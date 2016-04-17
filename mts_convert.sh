#!/usr/bin/env bash

# ------------------------------------------------------------
# Startup constants.
# ------------------------------------------------------------

# Random sting for random naming.
readonly RANDOM_STING=$(cat /dev/urandom \
    | tr -dc "A-Za-z0-9" \
    | fold -c8 \
    | head -n 1
)

# Time of script start for time based naming.
readonly START_TIME_STRING=$(date "+%Y-%m-%d_%H-%M-%S-%N")

readonly START_TIME_NS=$(($(date +%s%N)))


readonly SCRIPT_NAME=$(basename $0);

# ------------------------------------------------------------
# Default options:
#   They are not `readonly` because they can be
#       redefined via command line arguments.
# ------------------------------------------------------------

VERBOSE='true';
DRY_RUN='false';
CONFIG_FILE_NAME='';
INPUT_FILE_NAME_LIST='';
OUTPUT_DIR_NAME='';
OUTPUT_FILE_NAME='';
PASS_LOG_FILE_PREFIX=''
PASS_LOG_DIR_NAME="/tmp/${SCRIPT_NAME}/${RANDOM_STING}";


usage () {

    local title="${COLOR_BOLD}${SCRIPT_NAME}${COLOR_OFF}";
    echo -e "
${title} — simple bulk configurable ffmpeg-based video converter.

${COLOR_BOLD}Usage:${COLOR_OFF}
    ${SCRIPT_NAME} [options] [filenames]

${COLOR_BOLD}Options:${COLOR_OFF}
    -h, --help          shows this test.
    -i, --input         name of input video file
                        It supports mask.
    -o, --output        prefix of output video file.
    -O, --output-dir    output folder.
    -L, --pass-log-dir  passlog folder.
    -c, --config        yaml-config file.
    -v, --verbose       uses verbose mode.
                        It tells about really actions.
    -q, --quiet         uses quiet mode.
                        It disables quiet verbose mode.
    -d, --dry-run       uses dry-run mode.
                        It do not run anything.

    ";
}


default_config() {
    handle_config <<EOF
ffmpeg:
    bin: /usr/bin/ffmpeg
    threads: 0
    time: 10
profile:
    default:
        suffix: hd1
        video:
            width: 1280
            height:  720
            bitrate: 2000k
            preset: veryslow
            pass1:
                params: -weightp 2 -bf 3
            h264:
                profile: main
                level: 3.1
        audio:
            channels: 5.1
            bitrate: 320k
            volume: 4
            aac:
                profile: aac_he
EOF
}

# ------------------------------------------------------------
# Main function
# ------------------------------------------------------------
main(){
    configure "${@}"
    assert_not_empty "${INPUT_FILE_NAME_LIST}" 'empty input file list';
    for input_file_name in ${INPUT_FILE_NAME_LIST} ; do
        assert_exists \
            "${input_file_name}"    \
            "cannot find such file: ${input_file_name}. '$output_format'"
        verbose_start "${input_file_name}";
        for profile in "${!PROFILE_MAP[@]}"; do
            local abstract=$(plain_profile $profile abstract);
            if [[ -z ${abstract} ]]; then
                handle_profile "${profile}" "${input_file_name}"
            fi;
        done;
        verbose_end "${input_file_name}";
    done;
}

# ------------------------------------------------------------
# Function for handling one profile item
# ------------------------------------------------------------

handle_profile(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local step_name="${profile_name,,}"

    local suffix=$(profile_default  \
        "${step_name}"              \
        "${profile_name}"           \
        'suffix'
    );

    local passes=$(profile_default \
        '1' "$profile_name" 'passes');

    local output_format=$(profile_default \
        'mp4' "$profile_name" 'output_format');

    local extention=$(profile_default \
        "$output_format" "$profile_name" 'extention');

    local output_file_name=$(compute_if_empty \
        "${OUTPUT_FILE_NAME}" \
        "${input_file_name}" \
        "${OUTPUT_DIR_NAME}"  \
        "${suffix}" \
        "${extention}" );

    local pass_log_file_prefix=$(compute_if_empty \
        "${PASS_LOG_FILE_PREFIX}" \
        "${input_file_name}" \
        "${PASS_LOG_DIR_NAME}"  \
        "${suffix}");

    verbose_start "profile ${step_name}@%2s";

    local parallel_bin='';
    parallel_bin+=$(if_exists '%s --no-notice' ${PARALLEL_BIN});
    parallel_bin+=$(if_exists '-j %s' ${PARALLEL_MAX_PROCS});


    local global_options=$(handle_global_options    \
        "${profile_name}"                           \
        "${input_file_name}"                        \
    );

    local video_options=$(handle_video_options  \
        "${profile_name}"                       \
        "${input_file_name}"                    \
    );
    local audio_options=$(handle_audio_options  \
        "${profile_name}"                       \
        "${input_file_name}"                    \
    );
    verbose_start "passes@%4s";
    for pass in $(seq 1 ${passes}); do
        local pass_options="";
        local output_pass_file_name="${output_file_name}";
        if [[ ${passes} > 1 ]]; then
            pass_options="-pass ${pass} -passlogfile  ${pass_log_file_prefix}";
            if [[ ${pass} <  ${passes} ]]; then
                output_pass_file_name="/dev/null"
            fi;
        fi;
        verbose_run "pass ${pass}@%6s"  "${parallel_bin}" \
            ${FFMPEG_BIN} \
            ${global_options} \
            -i ${input_file_name} \
            ${video_options} \
            ${pass_options} \
            ${audio_options} \
            -f ${output_format} -y ${output_pass_file_name} ';'


    done
    verbose_end "passes@%4s";
    verbose_end "profile ${step_name}@%2s";
}

# ------------------------------------------------------------
# Global enconding functions
# ------------------------------------------------------------

handle_global_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local options="";
    options+=$(if_exists ' -ss %s' ${FFMPEG_START});
    options+=$(if_exists ' -t %s' ${FFMPEG_DURATION});
    options+=$(if_exists ' -threads %s' ${FFMPEG_THREADS});
    if [[ $(is_display ${input_file_name}) ]]; then
        options+='-f x11grab -s wxga '
    fi;

    verbose_block "global@%4s" "${options}";
    echo ${options};
}

# ------------------------------------------------------------
# Video functions
# ------------------------------------------------------------

handle_video_options(){
    # DEFAULT_video_options_265
    #     -codec:v libx265
    #     -preset veryslow
    #     -b:v 500k
    #     -maxrate 500k
    #     -bufsize 1000k
    #     -vf scale=-1:720
    #
    #
    # DEFAULT_video_options_264
    #     -codec:v libx264
    #     -preset veryslow
    #     -b:v 500k
    #     -maxrate 500k
    #     -bufsize 1000k
    #     -vf scale=-1:720
    #     -profile:v high


    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_options=$(handle_video_codec_options $profile_name);

    local preset="$(profile $profile_name video preset)";
    local bitrate="$(profile $profile_name video bitrate)";
    local bufsize="$(profile $profile_name video bufsize)";
    local maxrate="$(profile $profile_name video maxrate)";

    local width="$(profile $profile_name video width)";
    local height="$(profile $profile_name video height)";

    local common_options=""

    common_options+=$(if_exists '-preset %s' $preset)
    common_options+=$(if_exists '-maxrate %s' $maxrate)
    common_options+=$(if_exists '-bufsize %s' $bufsize)

    common_options+=$(if_exists '-vf "scale=%s:%s"' $width $height)


    local options="${common_options} ${codec_options}";
    verbose_block "video@%4s" "${options}";
    echo ${options}
}


handle_video_codec_options(){
    local name=$1;

    local codec_name=$(profile_default 'h264' $name video codec name)

    local codec_options="";

    if [[ "$codec_name" == "h264" ]]; then
        codec_options+=$(handle_video_h264_options $name);
    fi;

    echo "${codec_options}"
}

handle_video_h264_options(){
    # -profile:v = baseline, main, high, high10, high422, high444

    local name=$1;

    local codec_options='';

    local profile=$(profile $name video codec profile)
    local level=$(profile $name video codec level)

    local weightp=$(profile $name video codec weightp)
    local bframes=$(profile $name video codec bframes)


    local opts=$(profile $name video codec opts)


    codec_options+='-codec:v libx264';
    codec_options+=$(if_exists '-profile:v %s' $profile);
    codec_options+=$(if_exists '-level:v %s' $level);

    codec_options+=$(if_exists '-weightp %s' $weightp);
    codec_options+=$(if_exists '-bf %s' $bframes);

    codec_options+=$(if_exists '-x264opts "%s"' $opts);



    echo "${codec_options}"
}

# ------------------------------------------------------------
# Audio functions
# ------------------------------------------------------------

handle_audio_options(){
    local profile_name="${1}";
    local input_file_name="${2}";


    local bitrate="$(profile $profile_name audio bitrate)";
    local volume="$(profile $profile_name audio volume)";
    local common_options="";

    common_options+=$(if_exists '-b:a %s' $bitrate)
    common_options+=$(if_exists '-af "volume=%s"' ${volume})

    local codec_options=$(handle_audio_codec_options $profile_name)
    local options="${common_options} ${codec_options}";

    verbose_block "audio@%4s" "${options}";

    echo ${options}
}


handle_audio_codec_options(){
    local name=$1;

    local codec_name=$(profile_default 'aac' $name audio codec name)

    local codec_options="";

    codec_options+="-strict experimental ";
    codec_options+="-codec:a ${codec_name} ";


    echo "${codec_options}"
}


# ------------------------------------------------------------
# Profile fields access functions
# ------------------------------------------------------------

profile_if_exists() {
    local output_format="${1}";
    local value=$(profile ${@:2});
    if [[ -n "${value}" && "${value}" != "null" ]] ; then
        printf " ${output_format} " "${value}";
    fi;
}

if_exists() {
    local output_format="${1}";
    local value="${@:2}";
    for var in "${@:2}" ;do
        if [[ -z "${var}" || "${var}" == "null" ]] ; then
            value='null';
        fi;
    done
    if [[ -n "${value}" && "${value}" != "null" ]] ; then
        printf " ${output_format} " ${value};
    fi;
}

profile_default () {
    local default="${1}";
    local value=$(profile "${@:2}");
    if [[ -z "${value}" ]] ; then
        echo "${default}";
    else
        echo "${value}";
    fi;
}

profile () {
    local name="${1}";
    local value=$(plain_profile "${name}" "${@:2}")
    if [[ -z "${value}" ]] ; then
        local parent=$(plain_profile "${name}" 'extends');
        if [[ -n "${parent}" ]] ; then
            value=$(profile "${parent}" "${@:2}");
        fi;
    fi;
    echo "${value}";
}

plain_profile () {
    echo $(get 'profile' "${@}");
}

get () {
    local string="${1}";
    for word in "${@:2}"; do
        string+="_${word}";
    done;
    local value="${string^^}";
    echo $(eval echo "\${${value}}");
}


# ------------------------------------------------------------
# Functions for check and compute filenames.
# ------------------------------------------------------------

compute_if_empty (){
    local out_file_name="${1}";
    if [[ -z "${out_file_name}" ]] ; then
        local initial_file_name="${2}";
        if [[ $(is_display ${initial_file_name}) ]]; then
            initial_file_name=$(echo $initial_file_name \
                | sed 's/[.]/-/g' | sed 's/[:]//g');
            initial_file_name="display-${initial_file_name}"
            initial_file_name+="-${START_TIME_STRING}"

        fi;
        local initial_dir_name="${3}";
        local suffix="${4}";
        local extention="${5}";
        assert_not_empty "${initial_file_name}" "empty base name";
        local base_file_name=$(basename "${initial_file_name}");
        local base_name="${base_file_name%.*}";
        if [[ -z "${extention}" ]] ; then
            extention="${base_file_name##*.}"
            extention="${extention,,}"
        fi;
        if [[ -n "${initial_dir_name}" ]]; then
            parent_dir_name=$(dirname "${initial_dir_name}");
            base_dir_name=$(basename "${initial_dir_name}");
            local out_dir_name="${parent_dir_name}/${base_dir_name}";
            if [[ ! -d "${out_dir_name}" ]]; then
                notice "creates directory ${out_dir_name}"
                mkdir -p "${out_dir_name}";
            fi;
            base_name="${out_dir_name}/${base_name}"
        fi;
        out_file_name="${base_name}.${extention}"
        if [[ -n "${suffix}" ]] ; then
            out_file_name="${base_name}-${suffix}.${extention}"
        fi;


    fi;
    echo "${out_file_name}";
}

assert_not_empty () {
    local out_file_name="${1}";
    local message="${2}";
    if [[ -z "${out_file_name}" ]] ; then
        wrong_usage "${message}";
    fi;
}

assert_exists () {
    local file_name="${1}";
    local message="${2}";

    if [[ $(is_display ${file_name}) ]]; then
        warn "uses display '${file_name}' as a file name"
    else
        if [[ ! -f "${file_name}" ]] ; then
            wrong_usage "${message}";
        fi;
    fi;
}


is_display () {
    local file_name="${1}";
    if [[ ${file_name:0:1} == ":" ]]; then
        echo 'true'
    else
        echo ''
    fi;
}
# ------------------------------------------------------------
# Config functions
# ------------------------------------------------------------

configure () {
    parse_options "${@}";
    local out_file_name="${CONFIG_FILE_NAME}";
    if [[ -n "${out_file_name}" ]]; then
        handle_config "${out_file_name}";
    else
        default_config;
    fi;
}

parse_options (){

    local OPTIONS=$(getopt \
        -o                                          \
            'i:o:c:O:L:hvqd'                        \
        --long                                      \
            'input:,                                \
            output:,                                \
            config:,                                \
            output-dir:,                            \
            pass-log-dir:,                          \
            help,                                   \
            verbose,                                \
            quiet,                                  \
            dry-run'                                \
        -n "$0"                                     \
        -- "${@}");

    eval set -- ${OPTIONS};

    #verbose_block 'options' "${OPTIONS}"

    while [[ -n ${OPTIONS} ]] ; do
        case ${1} in
            -h|--help)
                show_usage;
                shift;;
            -i|--input)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        INPUT_FILE_NAME_LIST="${2} ";
                        shift 2;;
                esac;;
            -o|--output)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        OUTPUT_FILE_NAME=${2};
                        shift 2;;
                esac;;
            -O|--output-dir)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        OUTPUT_DIR_NAME=${2};
                        shift 2;;
                esac;;
            -L|--pass-log-dir)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        PASS_LOG_DIR_NAME=${2};
                        shift 2;;
                esac;;
            -c|--config)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        CONFIG_FILE_NAME=${2};
                        shift 2;;
                esac;;
            -v|--verbose)
                VERBOSE='true';
                shift;;
            -d|--dry-run)
                DRY_RUN='true';
                readonly DRY_RUN;
                shift;;
            -q|--quiet)
                VERBOSE='false';
                shift;;
            '--'|'')
                shift 1;
                INPUT_FILE_NAME_LIST+="$@"
                break;;
            *) wrong_usage "Unknown parameter '${1}'.";;
        esac;
    done;

    readonly VERBOSE;
    readonly CONFIG_FILE_NAME;
    readonly OUTPUT_DIR_NAME;
    readonly INPUT_FILE_NAME_LIST;
    readonly OUTPUT_FILE_NAME;


}

handle_config() {
    local config="$@";
    local res=$(parse_config $config);
    # [[ "x${VERBOSE}" = "xtrue" ]] && echo -e $res | sed 's/; /;\n/gi';
    eval "${res}";
}

parse_config() {
    local prefix="$2";
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/4; # indent size
        tail = toupper($2);
        vname[indent] = tail;
        for (i in vname) {
            if (i > indent) {
                delete vname[i]
            }
        }
        #if (length($3) > 0) {
            vn="'$prefix'";
            for (i=0; i<indent; i++) {
                vn=(vn)(vname[i])("_")
                vnn = vname[i+1]
                if (!(vn in varray)){
                    printf("declare -gA %sMAP; ", vn);
                }
                varray[vn] = 1
                if (!((vn,vnn) in varray)){
                    printf("%sMAP[%s]=\"%s\"; ", vn, vnn, $3);
                }
                varray[vn,vnn] = 1
            }
            printf("readonly %s%s=\"%s\"; ", vn, tail, $3);
        #}
    }';
}

# ------------------------------------------------------------
# Printing functions
# ------------------------------------------------------------

# All log-output into `stderr`
readonly OUT_LOG_STREAM=2;

LOG_OFFSET=''

# Colors works only in console.
if [ -t ${OUT_LOG_STREAM} ]; then
    readonly COLOR_OFF='\e[0m';      # Text Reset

    readonly COLOR_DARK_BLACK='\e[30m';
    readonly COLOR_DARK_RED='\e[31m';
    readonly COLOR_DARK_GREEN='\e[32m';
    readonly COLOR_DARK_YELLOW='\e[33m';
    readonly COLOR_DARK_BLUE='\e[34m';
    readonly COLOR_DARK_MAGENTA='\e[35m';
    readonly COLOR_DARK_CYAN='\e[36m';
    readonly COLOR_DARK_GRAY='\e[37m';

    readonly COLOR_LIGHT_BLACK='\e[90m';
    readonly COLOR_LIGHT_RED='\e[91m';
    readonly COLOR_LIGHT_GREEN='\e[92m';
    readonly COLOR_LIGHT_YELLOW='\e[93m';
    readonly COLOR_LIGHT_BLUE='\e[94m';
    readonly COLOR_LIGHT_MAGENTA='\e[95m';
    readonly COLOR_LIGHT_CYAN='\e[96m';
    readonly COLOR_LIGHT_GRAY='\e[97m';

    readonly BG_COLOR_DARK_BLACK='\e[40m';
    readonly BG_COLOR_DARK_RED='\e[41m';
    readonly BG_COLOR_DARK_GREEN='\e[42m';
    readonly BG_COLOR_DARK_YELLOW='\e[43m';
    readonly BG_COLOR_DARK_BLUE='\e[44m';
    readonly BG_COLOR_DARK_MAGENTA='\e[45m';
    readonly BG_COLOR_DARK_CYAN='\e[46m';
    readonly BG_COLOR_DARK_GRAY='\e[47m';

    readonly BG_COLOR_LIGHT_BLACK='\e[100m';
    readonly BG_COLOR_LIGHT_RED='\e[101m';
    readonly BG_COLOR_LIGHT_GREEN='\e[102m';
    readonly BG_COLOR_LIGHT_YELLOW='\e[103m';
    readonly BG_COLOR_LIGHT_BLUE='\e[104m';
    readonly BG_COLOR_LIGHT_MAGENTA='\e[105m';
    readonly BG_COLOR_LIGHT_CYAN='\e[106m';
    readonly BG_COLOR_LIGHT_GRAY='\e[107m';

    readonly COLOR_BOLD='\e[1m';
    readonly COLOR_DIM='\e[2m';
    readonly COLOR_UNDERLINED='\e[4m';
    readonly COLOR_REVERSE='\e[7m';
    readonly COLOR_DEL='\e[9m';
fi;

show_usage(){
    usage;
    exit 0;
}

wrong_usage(){
    usage;
    error "${@}";
    exit 3;
}

verbose() {
    if [[ "x${VERBOSE}" = "xtrue" ]] ; then
        printf "${@}\n"  \
            1>& ${OUT_LOG_STREAM};
    fi
}

verbose_offset (){
    LOG_OFFSET="${1}";
    verbose "${1}${2}";
}

verbose_inside (){
    verbose_offset "${1}  " "${2}";
}

verbose_start (){
    local string=$1;
    local delimiter='@';
    local name=$(awk -F "$delimiter" '{print $1}' <<< "$string")
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    verbose_offset "${offset}"\
    "${COLOR_LIGHT_MAGENTA}${name}:${COLOR_OFF}";
}

verbose_end (){
    local string=$1;
    local delimiter='@';
    local name=$(awk -F "$delimiter" '{print $1}' <<< "$string")
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    verbose_offset "${offset}"\
    "${COLOR_DARK_GREEN}# ${name} done${COLOR_OFF}";
}

verbose_block (){
    local string=$1;
    local delimiter='@';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    local value=${@:2}
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_BOLD}${COLOR_DARK_CYAN}${value}${COLOR_OFF}";
    verbose_end "${string}";
}

verbose_run (){
    local string="${1}";
    local executor="${2}";

    if [[ -z "${executor}" ]]; then
        executor='eval';
    fi;

    local offset='';
    local delimiter='@';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string");
    local value="${@:3}";
    local COLOR_ON="${COLOR_BOLD}${COLOR_LIGHT_YELLOW}"
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_ON}${executor} ${value}${COLOR_OFF}";
    if [[ "x${DRY_RUN}" = "xfalse" ]]; then
        if [[ "x${VERBOSE}" = "xtrue" ]]; then
            ${executor} "${value}";
        fi;
        if [[ "x${VERBOSE}" = "xfalse" ]]; then
            ${executor} "${value}" 2> /dev/null
        fi;
    fi;
    verbose_end "${string}";
}


success () {
    info_print  'SUCCESS'\
                "${NONE}"\
                "${COLOR_DARK_GREEN}"\
                "${COLOR_LIGHT_GREEN}"\
                "${@}"
}

fail () {
    info_print  'FAIL'\
                "${NONE}"\
                "${COLOR_DARK_RED}"\
                "${COLOR_LIGHT_RED}"\
                "${@}"
}

error () {
    info_print  'ERROR'\
                "${BG_COLOR_DARK_RED}"\
                "${COLOR_DARK_YELLOW}"\
                "${COLOR_LIGHT_RED}"\
                "${@}"
}

warn () {
    info_print  'WARNING'\
                "${BG_COLOR_LIGHT_YELLOW}"\
                "${COLOR_DARK_RED}"\
                "${COLOR_LIGHT_YELLOW}"\
                "${@}"
}

notice() {
    local NS=$(($(date +%s%N)-${START_TIME_NS}))
    local MS=$((${NS}/1000000))
    info_print  "NOTICE ${MS}"\
                "${BG_COLOR_DARK_BLUE}"\
                "${COLOR_DARK_CYAN}"\
                "${COLOR_LIGHT_CYAN}"\
                "${@}"
}


info_print() {


    local LABEL_TEXT="${1}";
    local MESSAGE_TEXT="${@:4}";
    local LABLE_COLOR="${COLOR_BOLD}${2}${3}";
    local LABEL="${LABLE_COLOR}# ${LABEL_TEXT}:${COLOR_OFF}";
    local WHERE_COLOR="${4}";
    local WHERE="${WHERE_COLOR} ${SCRIPT_NAME}${COLOR_OFF}";
    local MESSAGE_COLOR="${4}";
    local MESSAGE="${MESSAGE_COLOR}${MESSAGE_TEXT}${COLOR_OFF}";
    printf "${LOG_OFFSET}${LABEL} ${WHERE}${MESSAGE}\n" \
        1>& ${OUT_LOG_STREAM};

}



# ------------------------------------------------------------
# Main function call.
# ------------------------------------------------------------

main "${@}";


#
# ffmpeg -i inputfile.avi
# -codec:v libx264
# -profile:v main
# -preset slow -b:v 400k
# -maxrate 400k
# -bufsize 800k
# -vf scale=-1:480
# -threads 0 -codec:a
# libfdk_aac -b:a 128k output.mp4
#
# X="d"
# "d";
#







