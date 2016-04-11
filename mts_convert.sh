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
readonly START_TIME=$(date "+%Y-%m-%d_%H-%M-%S-%N")

# ------------------------------------------------------------
# Default options:
#   They are not `readonly` because they can be
#       redefined via command line arguments.
# ------------------------------------------------------------

VERBOSE='true';
DRY_RUN='false';
CONFIG_FILE_NAME='';
INPUT_FILE_NAME='';
OUTPUT_DIR_NAME='';
OUTPUT_FILE_NAME='';
PASS_LOG_FILE_PREFIX=''
PASS_LOG_DIR_NAME="/tmp/${0}/${RANDOM_STING}";


usage () {
    echo -e "${COLOR_BOLD}$0${COLOR_OFF} ${COLOR_DIM}<...>${COLOR_OFF}

    -h, --help          shows this test.
    -i, --input         name of input video file.
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
    assert_not_empty "${INPUT_FILE_NAME}" 'empty input file (-i)';
    for profile in "${!PROFILE_MAP[@]}"; do
        local abstract=$(plain_profile $profile abstract);
        if [[ -z ${abstract} ]]; then
            handle_profile $profile
        fi;
    done
}

# ------------------------------------------------------------
# Function for handling one profile item
# ------------------------------------------------------------

handle_profile(){
    local name="${1}";
    local suffix=$(profile_default "${name,,}" "$name" 'suffix');
    local passes=$(profile_default '1' "$name" 'passes');
    local format=$(profile_default 'mp4' "$name" 'format');
    local output_out_file_name=$(compute_if_empty \
        "${OUTPUT_FILE_NAME}" \
        "${INPUT_FILE_NAME}" \
        "${OUTPUT_DIR_NAME}"  \
        "${suffix}" \
        "${format}" );
    local pass_log_file_prefix=$(compute_if_empty \
        "${PASS_LOG_FILE_PREFIX}" \
        "${INPUT_FILE_NAME}" \
        "${PASS_LOG_DIR_NAME}"  \
        "${suffix}");
    verbose_start "profile n=${name,,} s=${suffix} f=${format}";

    local global_options="";
    global_options+=$(if_exists ' -t %s' ${FFMPEG_TIME})
    global_options+=$(if_exists ' -threads %s' ${FFMPEG_THREADS})

    local video_options=$(handle_video_options "$name");
    local audio_options=$(handle_audio_options "$name");
    verbose_start "passes:%2s";
    for pass in $(seq 1 ${passes}); do
        local pass_options="";
        if [[ ${passes} > 1 ]]; then
            pass_options="-pass ${pass} -passlogfile  ${pass_log_file_prefix}";
        fi;
        verbose_run "ffmpeg:%4s" ${FFMPEG_BIN} \
            ${global_options} \
            -i ${INPUT_FILE_NAME} \
            ${video_options} \
            ${pass_options} \
            ${audio_options} \
            -f ${format} -y ${output_out_file_name};
    done
    verbose_end "passes:%2s";
    verbose_end "profile n=${name,,} s=${suffix} f=${format}";
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


    local name=$1;

    local codec_options=$(handle_video_codec_options $name);

    local preset="$(profile $name video preset)";
    local bitrate="$(profile $name video bitrate)";
    local width="$(profile $name video width)";
    local height="$(profile $name video height)";

    local common_options=""

    common_options+=$(if_exists '-preset %s' $preset)
    common_options+=$(if_exists '-b:v %s' $bitrate)
    common_options+=$(if_exists '-vf "scale=%s:%s"' $width $height)


    local options="${common_options} ${codec_options}";

    verbose_block "video:%2s" "${options}";
    echo ${options}
}


handle_video_codec_options(){
    local name=$1;

    local codec_name=$(profile_default 'libx264' $name video codec name)

    local codec_options="-codec:v ${codec_name}";

    if [[ "$codec_name" == "libx264" ]]; then
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
    local opts=$(profile $name video codec opts)

    codec_options+=$(if_exists '-profile:v %s' $profile)
    codec_options+=$(if_exists '-level:v %s' $level)
    codec_options+=$(if_exists '-x264opts "%s"' $opts)

    echo "${codec_options}"
}

# ------------------------------------------------------------
# Audio functions
# ------------------------------------------------------------

handle_audio_options(){
    local name=$1;
    local bitrate="$(profile $name audio bitrate)";
    local volume="$(profile $name audio volume)";
    local common_options="";

    common_options+=$(if_exists '-b:a %s' $bitrate)
    common_options+=$(if_exists '-af "volume=%s"' ${volume})

    local codec_options=$(handle_audio_codec_options $name)
    local options="${common_options} ${codec_options}";

    verbose_block "audio:%2s" "${options}";

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
    local format="${1}";
    local value=$(profile ${@:2});
    if [[ -n "${value}" && "${value}" != "null" ]] ; then
        printf " ${format} " "${value}";
    fi;
}

if_exists() {
    local format="${1}";
    local value="${@:2}";
    for var in "${@:2}" ;do
        if [[ -z "${var}" || "${var}" == "null" ]] ; then
            value='null';
        fi;
    done
    if [[ -n "${value}" && "${value}" != "null" ]] ; then
        printf " ${format} " ${value};
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

    local OPTIONS=$(getopt -o i:o:c:O:L:hvqd        \
        --long                                      \
            'input:,output:,config:,'               \
            'output-dir:,pass-log-dir:'             \
            'help,verbose,quiet,dry-run'            \
         "$0" -- "${@}");

    #set -- ${OPTIONS};

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
                        INPUT_FILE_NAME=${2};
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
                break;;
            *) wrong_usage "Unknown parameter '${1}'.";;
        esac;
    done;

    readonly VERBOSE;
    readonly CONFIG_FILE_NAME;
    readonly OUTPUT_DIR_NAME;
    readonly INPUT_FILE_NAME;
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
        printf "${COLOR_DARK_GREEN}#${COLOR_OFF} ${@}\n"  \
            1>& ${OUT_LOG_STREAM};
    fi
}

verbose_offset (){
    verbose "${1}${2}";
}

verbose_inside (){
    verbose_offset "${1}  " "${2}";
}

verbose_start (){
    local string=$1;
    local delimiter=':';
    local name=$(awk -F "$delimiter" '{print $1}' <<< "$string")
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    verbose_offset "${offset}"\
    "${COLOR_LIGHT_MAGENTA}<${name}>${COLOR_OFF}";
}

verbose_end (){
    local string=$1;
    local delimiter=':';
    local name=$(awk -F "$delimiter" '{print $1}' <<< "$string")
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    verbose_offset "${offset}"\
    "${COLOR_LIGHT_MAGENTA}</${name}>${COLOR_OFF}";
}

verbose_block (){
    local string=$1;
    local delimiter=':';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string")
    local value=${@:2}
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_BOLD}${COLOR_DARK_CYAN}${value}${COLOR_OFF}";
    verbose_end "${string}";
}

verbose_run (){
    local string="${1}";
    local offset='';
    local delimiter=':';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string");
    local value="${@:2}";
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_BOLD}${COLOR_LIGHT_YELLOW}${value}${COLOR_OFF}";
    if [[ "x${DRY_RUN}" = "xfalse" ]]; then
        if [[ "x${VERBOSE}" = "xtrue" ]]; then
            $(eval "${value}");
        fi;
        if [[ "x${VERBOSE}" = "xfalse" ]]; then
            $(eval "${value}") 2> /dev/null
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
    info_print  'FAIL\t'\
                "${NONE}"\
                "${COLOR_DARK_RED}"\
                "${COLOR_LIGHT_RED}"\
                "${@}"
}

error () {
    info_print  'ERROR\t'\
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
    info_print  'NOTICE\t'\
                "${BG_COLOR_DARK_BLUE}"\
                "${COLOR_DARK_CYAN}"\
                "${COLOR_LIGHT_CYAN}"\
                "${@}"
}

info_print() {
    local LABEL_TEXT="${1}";
    local MESSAGE_TEXT="${@:4}";
    local LABLE_COLOR="${COLOR_BOLD}${2}${3}";
    local LABEL="${LABLE_COLOR} ${LABEL_TEXT}:${COLOR_OFF}";
    local WHERE_COLOR="${4}";
    local WHERE="${WHERE_COLOR}${0}${COLOR_OFF}";
    local MESSAGE_COLOR="${4}";
    local MESSAGE="${MESSAGE_COLOR}${MESSAGE_TEXT}${COLOR_OFF}";
    echo -e "${LABEL} ${WHERE} ${MESSAGE}" 1>& ${OUT_LOG_STREAM};
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






