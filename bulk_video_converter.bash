#!/usr/bin/env bash

# ------------------------------------------------------------
# Startup constants.
# ------------------------------------------------------------

# Random sting for random naming.
readonly RANDOM_STING=$(cat /dev/urandom \
    | tr -dc "A-Za-z0-9" \
    | fold -c8 \
    | head -n 1
);
# Time of script start for time based naming.
readonly START_TIME_STRING=$(date "+%Y-%m-%d_%H-%M-%S-%N");
readonly START_TIME_NS=$(($(date +%s%N)));
readonly SCRIPT_NAME=$(basename $0);
readonly FROM_CONFIG_FILE_FLAG="FROM-CONFIG-${RANDOM_STING}"
# ------------------------------------------------------------
# Default options:
#   They are not `readonly` because they can be
#       redefined via command line arguments.
# ------------------------------------------------------------

declare VERBOSE='true';
declare DRY_RUN='false';

declare CONFIG_FILE_NAME;
declare INPUT_FILE_NAME_LIST;
declare OUTPUT_DIR_NAME;
declare OUTPUT_FILE_NAME;
declare PASS_LOG_FILE_PREFIX;

declare LOG_DIR_BASE_NAME="/var/log/${SCRIPT_NAME}";
declare LOG_DIR_NAME="${LOG_DIR_BASE_NAME}/${START_TIME_STRING}"

declare TMP_DIR_BASE_NAME="/tmp/${SCRIPT_NAME}"
declare TMP_DIR_NAME="${TMP_DIR_BASE_NAME}/${RANDOM_STING}";
declare PASS_LOG_DIR_NAME="${TMP_DIR_NAME}/pass-log";

# ------------------------------------------------------------
# Internal global variables.
# ------------------------------------------------------------

declare -g  FFMPEG_BIN;
declare -g  FFMPEG_START;
declare -g  FFMPEG_DURATION;
declare -g  FFMPEG_THREADS;
declare -gA PROFILE_MAP;

declare -g  FILE_LOG_PREFIX="${TMP_DIR_NAME}/file-log";
declare -g  PROFILE_LOG_PREFIX="${TMP_DIR_NAME}/profile-log";

usage() {
    local C0="${COLOR_OFF}"
    local IC="${COLOR_BOLD}${COLOR_LIGHT_CYAN}"

    local AC="${COLOR_UNDERLINED}${COLOR_LIGHT_GREEN}"
    local EC="${COLOR_DARK_YELLOW}"
    local ETC="${COLOR_LIGHT_YELLOW}"

    local MC="${COLOR_UNDERLINED}"
    local FC="${COLOR_UNDERLINED}"
    local WC="${COLOR_DARK_YELLOW}"
    local WTC="${COLOR_LIGHT_YELLOW}"

    local title="${COLOR_BOLD}${SCRIPT_NAME}${C0}";
    echo -e "
${title} — simple bulk configurable ffmpeg-based video converter.
It uses YAML configuration for generating several output files from
one (or more) input video file. Each output file is created according
to «profile» subsection in YAML configuration. See profile example
in the ${FC}'default_config'${C0} function in this script.

The main purpose of this tool to create several videos of different
quality and size from one source. It is very helpful for handling raw
videos from amateur filming camera (especially *.MTS files).

${COLOR_REVERSE} Usage:${C0}
    ${SCRIPT_NAME} [options] [file names]

${COLOR_REVERSE} Options:${C0}
    ${IC}-i, --input${C0} ${AC}<filename.mp4|:0.0>${C0}
        name of input video file of display. It supports mask for
        file names. If several files are passed, they will be handled
        in parallel way. Mind this fact while operating the script.
        ${ETC}Examples:${C0}
            ${EC}${SCRIPT_NAME} -i ./video.mts${C0}
            ${EC}${SCRIPT_NAME} -i ./part1.mp4 ./part2.mp4${C0}
            ${EC}${SCRIPT_NAME} -i ~/Videos/*.mp4${C0}
            ${EC}${SCRIPT_NAME} -i :0.0${C0}
        Also you can set input files' names without '-i' option:
            ${EC}${SCRIPT_NAME} ./video.mts${C0}
            ${EC}${SCRIPT_NAME} ./part1.mp4 ./part2.mp4${C0}
            ${EC}${SCRIPT_NAME} ~/Videos/*.mp4${C0}
            ${EC}${SCRIPT_NAME} :0.0${C0}
        Also you can set input files' names within config file.
        For this you should define the 'source' field (or
        'source / video' or 'source / video / device') inside the
        profile.
    ${IC}-c, --config${C0}  ${AC}<filename.yaml>${C0}
        set yaml-config file for encoding profile. See examples in
        the  ${FC}'default_config'${C0} function in this script.
        ${ETC}Example:${C0}
            ${EC}${SCRIPT_NAME} ./video.mts -c ./config.yaml${C0}
        If several profiles are passed, they will be handled in
        parallel way.
    ${IC}-O, --output-dir${C0} ${AC}<dir name>${C0}
        folder for output files. If not set it uses current folder to
         save. ${ETC}Examples:${C0}
            ${EC}${SCRIPT_NAME} ./video.mts -O ./out/ ${C0}
    ${IC}-v, --verbose${C0}
        uses verbose mode. It prints detailed report about ffmpeg
        options and parameters in YAML format.
        ${WTC}NOTE:${C0}
          ${WC}Mind the fact that all files and profiles are handled
          in parallel. So, log lines can be mixed.${C0}
    ${IC}-q, --quiet${C0}
        uses quiet mode. It disables «verbose» mode.
    ${IC}-d, --dry-run${C0}
        uses dry-run mode. It do not run anything, but is extremely
        helpful. Several real ffmpeg launches on a real data can be
        very time-consuming. You can use this option with a verbose
        mode to check what will happen on a full launch.
    ${IC}-F, --ffmpeg-log-dir${C0} ${AC}<dir name>${C0}
        folder for ffmpeg logs.
        default is ${FC}'${LOG_DIR_BASE_NAME}'${C0}.
    ${IC}-h, --help${C0}
        shows this text.
    ${IC}-P, --pass-log-dir${C0} ${AC}<dir name>${C0}
        passlog folder. It uses only for several ffmpeg passes.
        If not set it uses is ${FC}'${TMP_DIR_BASE_NAME}'${C0}.
        ${WTC}WARNING:${C0}
          ${WC}There is no reason to set this option
          in a common situation.${C0}
    ${IC}-o, --output${C0} ${AC}<filename.mp4>${C0}
        name of output video file.
        ${WTC}WARNING:${C0}
          ${WC}There is no reason to set this option
          in a common situation.${C0}
${COLOR_REVERSE} Authors:${C0}
    Ilya w495 Nikitin.
    Report bugs to:
        ${MC}w@w-495.ru${C0}
        ${MC}w-495@yandex.ru${C0}
    " 1>& ${OUT_LOG_STREAM};
}

default_config() {
    handle_config <<EOF
ffmpeg:
  bin: /usr/bin/ffmpeg
  threads: 0
  start: 00:00:05
  duration: 00:00:10
profile:
  base:
    # you can mark profile as abstract
    # and it will be used only for inheritance.
    abstract: 1
    passes: 2
    video:
      preset: veryfast
      codec:
        name : h264
        weightp: 2
        bframes: 3
        opts: "keyint=96:min-keyint=96:no-scenecut"
    audio:
      codec:
        name: aac
  default:
    # Other options are inherited from base
    extends: base
    video:
      width: 480
      height:  270
      bitrate: 250k
      codec:
        profile: baseline
        level: 3.0
    audio:
      channels: 1
      bitrate: 64k
EOF
}

# ------------------------------------------------------------
# Main function
# ------------------------------------------------------------

main(){
    $(verbose_start "${SCRIPT_NAME}");

    # non-local function `configure` — sets global options of script.
    configure "${@}";

    $(start_up);
    $(handle_file_sequence "${INPUT_FILE_NAME_LIST}");
    $(clean_up);
    $(verbose_end "${SCRIPT_NAME}");
}

handle_file_sequence(){
    local file_name_sequence="${1}";
    local concrete_profile="${2}";

    local file_log_prefix="${FILE_LOG_PREFIX}";

    if [[ -n ${concrete_profile} ]]; then
        file_log_prefix="${file_log_prefix}-${concrete_profile}"
    fi;

    local -i file_index=1;
    for file_name in ${file_name_sequence} ; do
        # Handle each file in parallel.  But log about it sequentially.
        $(handle_file_async                                         \
            "${file_name}"                                          \
            "${file_index}"                                         \
            "${file_log_prefix}-${file_index}"  \
            "${concrete_profile}"                                   \
        ) &
        file_index+=1
    done;
    wait;

    if [[ -z ${concrete_profile} ]]; then
        cat ${file_log_prefix}* 1>& ${OUT_LOG_STREAM}
    fi;

}


handle_file_async(){
    local input_file_name="${1}";
    local file_index="${2}";
    local file_log="${3}";
    local concrete_profile="${4}";

    (
        $(handle_file   \
            "${input_file_name}"    \
            "${file_index}"         \
            "${concrete_profile}"   \
        );
    ) 2>"${file_log}.log" &
}


handle_file(){
    local input_file_name="${1}";
    local file_index="${2}";
    local concrete_profile="${3}";
    $(assert_exists                         \
        "${input_file_name}"                \
        "no such file: ${input_file_name}." \
    );
    $(verbose_start "${input_file_name} ${concrete_profile}@%2s");

    if [[ -n ${concrete_profile} ]]; then
        $(handle_concrete_profile   \
            "${concrete_profile}"       \
            "${input_file_name}"    \
        )
    else
        $(handle_profile_sequence   \
            "${input_file_name}"    \
            "${file_index}"         \
        );
    fi;

    $(verbose_end "${input_file_name} ${concrete_profile}@%2s");
}


handle_profile_sequence(){
    local input_file_name="${1}";
    local file_index="${2}";
    local profile_log_prefix="${PROFILE_LOG_PREFIX}-${file_index}";
    local -i profile_index=1;
    for profile_name in "${!PROFILE_MAP[@]}"; do
        $(handle_profile_async                                      \
            "${profile_name}"                                       \
            "${input_file_name}"                                    \
            "${profile_log_prefix}-${profile_index}"  \
        ) &
        profile_index+=1
    done;
    wait;
    cat ${profile_log_prefix}* 1>& ${OUT_LOG_STREAM}
}

handle_profile_async(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local profile_log="${3}";
    (
        $(handle_profile "${profile_name}" "${input_file_name}")
    ) 2>"${profile_log}.log" &
}


handle_profile(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local abstract=$(plain_profile ${profile_name} abstract);
    local is_complex=$(plain_profile "${name}" 'is_complex');
    if [[ -z ${abstract} ]]; then
        input_file_name=$(profile_default  \
            "${input_file_name}"                    \
            "${profile_name}"                       \
            source                                  \
        );
        input_file_name=$(profile_default  \
            "${input_file_name}"                    \
            "${profile_name}"                       \
            source                                  \
            video                                   \
        );
        input_file_name=$(profile_default  \
            "${input_file_name}"                    \
            "${profile_name}"                       \
            source                                  \
            video                                   \
            device                                  \
        );
        handle_file_sequence "${input_file_name}" "${profile_name}"
    fi;
}

# ------------------------------------------------------------
# Function for handling one profile item
# ------------------------------------------------------------

handle_concrete_profile(){
    local profile_name="${1}";
    local input_file_name="${2}";


    local step_name=$(echo "${profile_name}" \
        | tr '[:upper:]' '[:lower:]');

    verbose_start "profile ${step_name}@%4s";

    local suffix=$(profile_default  \
        "${step_name}"              \
        "${profile_name}"           \
        'suffix'
    );

    local passes=$(profile_default      \
        '1' "${profile_name}" 'passes');

    local output_format=$(profile_default \
        'mp4' "${profile_name}" 'output_format');

    local extention=$(profile_default \
        "$output_format" "${profile_name}" 'extention');

    local output_dir_name=$(profile_default             \
        "${OUTPUT_DIR_NAME}"                            \
        "${profile_name}"                               \
        output_dir_name                                 \
    );
    local output_file_name=$(compute_if_empty           \
        "${OUTPUT_FILE_NAME}"                           \
        "${input_file_name}"                            \
        "${output_dir_name}"                            \
        "${suffix}"                                     \
        "${extention}"
    );

    local pass_log_dir_name=$(profile_default           \
        "${PASS_LOG_DIR_NAME}"                          \
        "${profile_name}"                               \
        pass_log_dir_name                               \
    );
    local pass_log_file_prefix=$(compute_if_empty       \
        "${PASS_LOG_FILE_PREFIX}"                       \
        "${input_file_name}"                            \
        "${pass_log_dir_name}"                          \
        "${suffix}"                                     \
    );

    local global_input_options=$(handle_global_input_options    \
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

    local global_output_options=$(handle_global_output_options    \
        "${profile_name}"                           \
        "${input_file_name}"                        \
    );

    verbose_start "passes@%6s";
    for pass in $(seq 1 ${passes}); do
        local pass_options='';
        local output_pass_file_name="${output_file_name}";
        if [[ ${passes} > 1 ]]; then
            pass_options="-pass ${pass} -passlogfile  ${pass_log_file_prefix}";
            if [[ ${pass} <  ${passes} ]]; then
                output_pass_file_name="/dev/null"
            fi;
        fi;
        local log_file_name=$(compute_if_empty \
            "${OUTPUT_FILE_NAME}" \
            "${input_file_name}" \
            "${LOG_DIR_NAME}"  \
            "${suffix}-${pass}-${extention}" \
            "ffmpeg.log" );

        verbose_run "pass ${pass}@%8s"  \
            ${FFMPEG_BIN} \
            ${global_input_options} \
            "-i '${input_file_name}'" \
            ${video_options} \
            ${pass_options} \
            ${audio_options} \
            ${global_output_options}    \
            "-f '${output_format}'" \
            "-y '${output_pass_file_name}'" \
            "2>&1 | tee ${log_file_name} 1>&${OUT_LOG_STREAM};"
    done
    verbose_end "passes@%6s";
    verbose_end "profile ${step_name}@%4s";
}

# ------------------------------------------------------------
# Global encoding functions
# ------------------------------------------------------------

handle_global_input_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local options='';

    local start_position=$(profile_default      \
        "${FFMPEG_START}"                       \
        ${profile_name}                         \
        start                                   \
    );

    options+=$(if_exists " -ss '%s'" ${start_position});
    options+=$(if_exists " -threads '%s'" ${FFMPEG_THREADS});

    if [[ $(is_device ${input_file_name}) ]]; then
        local device_options=$(handle_global_device_options    \
            "${profile_name}"                                   \
            "${input_file_name}"                                \
        );
        options+="${device_options}"

    fi;

    verbose_block "global input@%6s" "${options}";
    echo ${options};
}


handle_global_output_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local options='';

    local start_position=$(profile_default      \
        "${FFMPEG_START}"                       \
        ${profile_name}                         \
        start                                   \
    );

    local duration=$(profile_default            \
        "${FFMPEG_DURATION}"                    \
        ${profile_name}                         \
        duration                                \
    );

    local stop_position=$(profile_default       \
        "${FFMPEG_STOP}"                        \
        ${profile_name}                         \
        stop                                    \
    );

    options+=$(if_exists " -ss '%s'" ${start_position});
    options+=$(if_exists " -t '%s'" ${duration});
    options+=$(if_exists " -to '%s'" ${stop_position});

    verbose_block "global output@%6s" "${options}";
    echo ${options};
}


handle_global_device_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local options='';

    local audio_input_format=$(profile_default  \
        'alsa'                      \
        ${profile_name}             \
        source                      \
        audio                       \
        format                      \
    );

    local audio_input_device=$(profile_default  \
        'hw:0'                      \
        ${profile_name}             \
        source                      \
        audio                       \
        device                      \
    );


    local video_input_format=$(profile_default  \
        'x11grab'                   \
        ${profile_name}             \
        source                      \
        video                       \
        format                      \
    );

    local video_input_size=$(profile_default  \
        'wxga'                      \
        ${profile_name}             \
        source                      \
        video                       \
        size                        \
    );


    options+=$(if_exists ' -f %s' ${audio_input_format});
    options+=$(if_exists ' -i %s' ${audio_input_device});

    options+=$(if_exists ' -f %s' ${video_input_format});
    options+=$(if_exists ' -s %s' ${video_input_size});


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

    local codec_options=$(handle_video_codec_options ${profile_name});

    local preset="$(profile ${profile_name} video preset)";
    local bitrate="$(profile ${profile_name} video bitrate)";
    local bufsize="$(profile ${profile_name} video bufsize)";
    local maxrate="$(profile ${profile_name} video maxrate)";
    local minrate="$(profile ${profile_name} video minrate)";


    local width="$(profile ${profile_name} video width)";
    local height="$(profile ${profile_name} video height)";

    local common_options=''

    common_options+=$(if_exists "-preset '%s'" ${preset})
    common_options+=$(if_exists "-b:v '%s'" ${bitrate})
    common_options+=$(if_exists "-maxrate '%s'" ${maxrate})
    common_options+=$(if_exists "-minrate '%s'" ${minrate})
    common_options+=$(if_exists "-bufsize '%s'" ${bufsize})

    common_options+=$(if_exists "-vf 'scale=%s:%s'" ${width} ${height})

    local options="${common_options} ${codec_options}";
    verbose_block "video@%6s" "${options}";
    echo ${options}
}


handle_video_codec_options(){
    local profile_name="${1}";
    local input_file_name="${2}";


    local codec_name=$(profile_default \
        'h264' \
        ${profile_name} video codec name
    );

    local codec_options='';

    if [[ "$codec_name" == "h264" ]]; then
        codec_options+=$(handle_video_h264_options ${profile_name});
    fi;

    echo "${codec_options}"
}

handle_video_h264_options(){
    # -profile:v = baseline, main, high, high10, high422, high444

    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_options='';

    local h264_profile=$(profile ${profile_name} video codec profile)
    local level=$(profile ${profile_name} video codec level)

    local weightp=$(profile ${profile_name} video codec weightp)
    local bframes=$(profile ${profile_name} video codec bframes)


    local opts=$(profile ${profile_name} video codec opts)


    codec_options+="-codec:v 'libx264'";
    codec_options+=$(if_exists "-profile:v '%s'" ${h264_profile});
    codec_options+=$(if_exists "-level:v '%s'" ${level});

    codec_options+=$(if_exists "-weightp '%s'" ${weightp});
    codec_options+=$(if_exists "-bf '%s'" ${bframes});

    codec_options+=$(if_exists "-x264opts '%s'" ${opts});



    echo "${codec_options}"
}

# ------------------------------------------------------------
# Audio functions
# ------------------------------------------------------------

handle_audio_options(){
    local profile_name="${1}";
    local input_file_name="${2}";


    local bitrate="$(profile ${profile_name} audio bitrate)";
    local volume="$(profile ${profile_name} audio volume)";

    local filter_options=$(handle_audio_filter_options \
       "${profile_name}"    \
       "${input_file_name}" \
    );
    local common_options='';

    common_options+=$(if_exists "-b:a '%s'" ${bitrate})

    common_options+=$(handle_audio_channels_options \
        ${profile_name}     \
        ${input_file_name}  \
    );

    common_options+=$(if_exists "-ac '%s'" ${channels})

    common_options+=$(if_exists "-filter:a '%s'" ${filter_options} )

    local codec_options=$(handle_audio_codec_options ${profile_name})
    local options="${common_options} ${codec_options}";

    verbose_block "audio@%6s" "${options}";

    echo ${options}
}

handle_audio_channels_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local channels="$(profile ${profile_name} audio channels)";

    case "${channels}" in
        mono)   channels='1';;
        stereo) channels='2';;
        5.1)    channels='6';;
        *) ;;
    esac;
    local channels_options=$(if_exists "-ac '%s'" ${channels})

    echo ${channels_options}
}

handle_audio_filter_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local volume="$(profile ${profile_name} audio volume)";

    local filter_options='';

    filter_options+=$(if_exists "volume='%s'" ${volume})

    echo "${filter_options}"
}

handle_audio_codec_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_name=$(profile_default \
        'aac' ${profile_name} audio codec name);

    local codec_options='';

    codec_options+="-strict 'experimental' ";
    codec_options+="-codec:a '${codec_name}' ";

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
    local field_name="${string^^}";
    local var_name=$(echo "\${${field_name}}")
    echo $(eval echo "${var_name}")
}


# ------------------------------------------------------------
# Functions for check and compute file names.
# ------------------------------------------------------------

compute_if_empty (){
    local out_file_name="${1}";
    if [[ -z "${out_file_name}" ]] ; then
        local initial_file_name="${2}";
        if [[ $(is_device ${initial_file_name}) ]]; then
            initial_file_name=$(echo ${initial_file_name} \
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
            extention=$(echo "${extention}" \
                | tr '[:upper:]' '[:lower:]');
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


start_up (){
    if [[ ! -d "${TMP_DIR_NAME}" ]] ; then
        notice "creates directory ${TMP_DIR_NAME}"
        mkdir -p "${TMP_DIR_NAME}";
    fi;
}

clean_up (){
    if [[ -d "${TMP_DIR_BASE_NAME}" ]] ; then
        notice "deletes directory ${TMP_DIR_BASE_NAME}"
        rm -rf "${TMP_DIR_BASE_NAME}";
    fi;

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

    if [[ $(is_device ${file_name}) ]]; then
        notice "uses display '${file_name}' as a file name"
    elif [[ "${file_name}" == "${FROM_CONFIG_FILE_FLAG}" ]] ; then
        notice "gets file names from config";
    elif [[ ! -f "${file_name}" ]] ; then
        wrong_usage "${message}";
    fi;
}




is_device () {
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
            'i:o:c:O:P:F:hvqd'                        \
        --long                                      \
            'input:,                                \
            output:,                                \
            config:,                                \
            output-dir:,                            \
            pass-log-dir:,                          \
            ffmpeg-log-dir:,                        \
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
            -P|--pass-log-dir)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        PASS_LOG_DIR_NAME=${2};
                        shift 2;;
                esac;;
            -F|--ffmpeg-log-dir)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        LOG_DIR_NAME=${2};
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
    readonly OUTPUT_FILE_NAME;
    readonly LOG_DIR_NAME;
    readonly PASS_LOG_DIR_NAME;

    if [[ -z "${INPUT_FILE_NAME_LIST}" ]]; then
        INPUT_FILE_NAME_LIST="${FROM_CONFIG_FILE_FLAG}"
    fi;

    readonly INPUT_FILE_NAME_LIST;

}

handle_config() {
    local config="$@";
    local res=$(parse_config ${config});
    #if [[ "${VERBOSE}" == "true" ]]; then
    #    echo -e ${res} | sed 's/; /;\n/gi';
    #fi;
    eval "${res}";

}

parse_config() {
    local prefix="$2";
    local s='[[:space:]]*';
    local w='[a-zA-Z0-9_-]*';
    local fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    sed  -E 's/\s+\#.*//' |
    awk -F${fs} '{
        indent = length($1)/2; # indent size
        tail = toupper($2);
        indent = gensub(/\W/, "_", "g", indent)
        tail = gensub(/\W/, "_", "g", tail)
        vname[indent] = tail;
        for (i in vname) {
            if (i > indent) {
                delete vname[i]
            }
        }
        vn="'${prefix}'";
        for (i=0; i<indent; i++) {
            vn=(vn)(vname[i])("_")
            vnn = vname[i+1]
            if (!(vn in varray)){
                printf("declare -gA %sMAP; ", vn);
            }
            varray[vn] = 1
            if (!((vn,vnn) in varray)){
                printf("%sMAP[\"%s\"]=\"%s\"; ", vn, vnn, $3);
            }
            varray[vn,vnn] = 1
        }
        printf("readonly %s%s=\"%s\"; ", vn, tail, $3);
    }' ;
}

# ------------------------------------------------------------
# Printing functions
# ------------------------------------------------------------

# All log-output into `stderr`
readonly OUT_LOG_STREAM=2;

declare -g LOG_OFFSET='';

# Colors works only in console.
if [ -t ${OUT_LOG_STREAM} ]; then
    readonly COLOR_NONE;
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
    if [[ "${VERBOSE}" == "true" ]] ; then
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
    local offset='';
    local delimiter='@';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string");
    local value="${@:2}";
    local COLOR_ON="${COLOR_BOLD}${COLOR_LIGHT_YELLOW}"
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_ON}${value}${COLOR_OFF}";
    if [[ "${DRY_RUN}" == "false" ]]; then
        if [[ "${VERBOSE}" == "true" ]]; then
            $(eval "${value}");
        fi;
        if [[ "${VERBOSE}" == "false" ]]; then
            $(eval "${value}") 2> /dev/null
        fi;
    fi;
    verbose_end "${string}";
}


success () {
    info_print  'SUCCESS'\
                "${COLOR_NONE}"\
                "${COLOR_DARK_GREEN}"\
                "${COLOR_LIGHT_GREEN}"\
                "${@}"
}

fail () {
    info_print  'FAIL'\
                "${COLOR_NONE}"\
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
    local LABEL_COLOR="${COLOR_BOLD}${2}${3}";
    local LABEL="${LABEL_COLOR}# ${LABEL_TEXT}:${COLOR_OFF}";
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








