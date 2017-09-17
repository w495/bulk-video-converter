#!/usr/bin/env bash

# trace ERR through pipes
set -o pipefail;

# trace ERR through 'time command' and other functions
set -o errtrace;

## exit the script if any statement returns a non-true return value
set -o errexit;

set -E


# ------------------------------------------------------------
# Startup constants.
# ------------------------------------------------------------

# Self name.
readonly SCRIPT_NAME=$(basename $0);
readonly SCRIPT_PID=$$;

# Random sting for random naming.
if [[ -v 'RANDOM_STRING' ]]; then
    echo "# ${SCRIPT_NAME}: use RANDOM_STRING from ENV:";
    echo "# ${SCRIPT_NAME}:     RANDOM_STRING='${RANDOM_STRING}'.";
else
    readonly RANDOM_STRING=$(cat /dev/urandom \
        | tr -dc "A-Za-z0-9" \
        | fold -c8 \
        | head -n 1
    );
fi;

# Time of script start for time based naming.
if [[ -v 'START_TIME_STRING' ]]; then
    echo "# ${SCRIPT_NAME}: use START_TIME_STRING from ENV:";
    echo "# ${SCRIPT_NAME}:     START_TIME_STRING='${START_TIME_STRING}'.";
else
    readonly START_TIME_STRING=$(date "+%Y-%m-%d_%H-%M-%S-%N");
fi;

readonly START_TIME_NS=$(($(date +%s%N)));



# Version for compatibility detection.
readonly VERSION='0.1505573195';

# Internal constants.
readonly TMP_DIR_BASE_NAME="/tmp/${SCRIPT_NAME}"
readonly TMP_DIR_NAME="${TMP_DIR_BASE_NAME}/${RANDOM_STRING}";


# ------------------------------------------------------------
# Default options:
#   They are not `readonly` because they can be
#       redefined via command line arguments.
# ------------------------------------------------------------

readonly LOG_DIR_BASE_NAME="/var/log/${SCRIPT_NAME}";
declare LOG_DIR_NAME="${LOG_DIR_BASE_NAME}/${START_TIME_STRING}"

readonly FILE_LOG_PREFIX="${LOG_DIR_NAME}/file-log";
readonly PROFILE_LOG_PREFIX="${LOG_DIR_NAME}/profile-log";

declare PASS_LOG_DIR_NAME="${TMP_DIR_NAME}/pass-log";

declare VERBOSE='true';
declare DRY_RUN='false';

declare CONFIG_FILE_NAME;
declare INPUT_FILE_NAME_LIST;
declare OUTPUT_DIR_NAME;
declare OUTPUT_FILE_NAME;
declare LOG_FILE_NAME;
declare PASS_LOG_FILE_PREFIX;

# ------------------------------------------------------------
#   They are not `readonly` because they can be
#       redefined via configuration file.
# ------------------------------------------------------------

declare FFMPEG_BIN='/usr/bin/ffmpeg';
declare FFMPEG_THREADS=1;
declare FFMPEG_START;
declare FFMPEG_STOP;
declare FFMPEG_DURATION;


declare ASYNC_FILES_DEFAULT='true';
declare ASYNC_PROFILES_DEFAULT='true';

declare SELF_IS_ASYNC;
declare SELF_IS_ASYNC_FILES;
declare SELF_IS_ASYNC_PROFILES;
declare SELF_NO_ASYNC;
declare SELF_NO_ASYNC_FILES;
declare SELF_NO_ASYNC_PROFILES;

declare -A PROFILE_MAP;

# ------------------------------------------------------------
# Internal global variables for color stderr printing
#   They are not `readonly` because they are redefined below.
# ------------------------------------------------------------

readonly FROM_CONFIG_FILE_NAME="input/files/are/from/config";
declare FROM_CONFIG_FLAG='';

# All log-output into `stderr`
readonly OUT_LOG_STREAM=2;

declare LOG_OFFSET;

declare COLOR_NONE;
declare COLOR_OFF;
declare COLOR_DARK_BLACK;
declare COLOR_DARK_RED;
declare COLOR_DARK_GREEN;
declare COLOR_DARK_YELLOW;
declare COLOR_DARK_BLUE;
declare COLOR_DARK_MAGENTA;
declare COLOR_DARK_CYAN;
declare COLOR_DARK_GRAY;
declare COLOR_LIGHT_BLACK;
declare COLOR_LIGHT_RED;
declare COLOR_LIGHT_GREEN;
declare COLOR_LIGHT_YELLOW;
declare COLOR_LIGHT_BLUE;
declare COLOR_LIGHT_MAGENTA;
declare COLOR_LIGHT_CYAN;
declare COLOR_LIGHT_GRAY;
declare BG_COLOR_DARK_BLACK;
declare BG_COLOR_DARK_RED;
declare BG_COLOR_DARK_GREEN;
declare BG_COLOR_DARK_YELLOW;
declare BG_COLOR_DARK_BLUE;
declare BG_COLOR_DARK_MAGENTA;
declare BG_COLOR_DARK_CYAN;
declare BG_COLOR_DARK_GRAY;
declare BG_COLOR_LIGHT_BLACK;
declare BG_COLOR_LIGHT_RED;
declare BG_COLOR_LIGHT_GREEN;
declare BG_COLOR_LIGHT_YELLOW;
declare BG_COLOR_LIGHT_BLUE;
declare BG_COLOR_LIGHT_MAGENTA;
declare BG_COLOR_LIGHT_CYAN;
declare BG_COLOR_LIGHT_GRAY;
declare COLOR_BOLD;
declare COLOR_DIM;
declare COLOR_UNDERLINED;
declare COLOR_REVERSE;
declare COLOR_DEL;

usage() {
    local C0="${COLOR_OFF}"
    local IC="${COLOR_BOLD}${COLOR_LIGHT_CYAN}"
    local OC="${COLOR_LIGHT_MAGENTA}"
    local AC="${COLOR_UNDERLINED}${COLOR_LIGHT_GREEN}"
    local EC="${COLOR_DARK_YELLOW}"
    local ETC="${COLOR_LIGHT_YELLOW}"
    local MC="${COLOR_UNDERLINED}"
    local FC="${COLOR_UNDERLINED}"
    local WC="${COLOR_DARK_YELLOW}"
    local WTC="${COLOR_LIGHT_YELLOW}"
    local title="${COLOR_BOLD}${SCRIPT_NAME}${C0}";
    echo -e "
${title} — simple configurable bulk ffmpeg-based video converter.
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
        in parallel way by default. (See ${OC}--no-async*${C0} options).
        Mind this fact while operating the script.
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
    ${IC}--no-async${C0}
        switch off asynchronous handling for files and profiles.
    ${IC}--no-async-files${C0}
        switch off asynchronous handling only for files.
    ${IC}--no-async-profiles${C0}
        switch off asynchronous handling only for profiles.
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
    ${IC}-f, --ffmpeg-log${C0} ${AC}<filename.log>${C0}
        name of ffmpeg log file.
        ${WTC}WARNING:${C0}
          ${WC}There is no reason to set this option
          in a common situation.${C0}
        However, you can use ${AC}/dev/null${C0} as a log file
        to see colored ffmpeg output.
    ${IC}--async${C0}
        switch on asynchronous handling for files and profiles.
        ${WTC}WARNING:${C0}
          ${WC}This is a default!
          There is no reason to set this option
          in a common situation.${C0}
        Use ${OC}--no-async*${C0} options to switch it off.
    ${IC}--async-files${C0}
        switch on asynchronous handling only for files.
        ${WTC}WARNING:${C0}
          ${WC}This is a default!
          There is no reason to set this option
          in a common situation.${C0}
        Use ${OC}--no-async*${C0} options to switch it off.
    ${IC}--async-profiles${C0}
        switch on asynchronous handling only for profiles.
        ${WTC}WARNING:${C0}
          ${WC}This is a default!
          There is no reason to set this option
          in a common situation.${C0}
        Use ${OC}--no-async*${C0} options to switch it off.
${COLOR_REVERSE} Version:${C0}
    ${VERSION}
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
    # you can mark profile as is_abstract
    # and it will be used only for inheritance.
    is_abstract: 1
    passes: 2
    video:
      codec:
        preset: veryfast
        name : h264
        weightp: smart
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

    $(verbose_block "datetime@%2s" "$START_TIME_STRING");

    # non-local function `configure` — sets global options of script.
    configure "${@}";

    check_versions;

    $(verbose_block "async_for_files@%2s" "$(use_async_for_files)");
    $(verbose_block "async_for_profiles@%2s" "$(use_async_for_profiles)");

    $(start_up);
    $(handle_file_sequence "${INPUT_FILE_NAME_LIST}")
    # $(clean_up);
    $(verbose_end "${SCRIPT_NAME}");
}


check_versions(){
    $(verbose_start "versions@%2s");
    local config_version="${SELF_COMPATIBILITY_FROM}";
    $(verbose_block "${SCRIPT_NAME}@%4s" "${VERSION}");
    $(verbose_block "config@%4s" "${config_version}");
    if [[ "${config_version}" !=  "${VERSION}" ]]; then
        warn "version (${VERSION}) do not match" \
            "config version (${config_version}).";
        if [[  "${VERSION#0.}" -lt "${config_version#0.}" ]]; then
            error "version (${VERSION}) less then the smallest" \
                "compatibility config version (${config_version}).";
        fi;
    fi;
    $(verbose_end "versions@%2s");
}

handle_file_sequence(){
    local file_name_sequence="${1}";
    local concrete_prof="${2}";
    local profile_map_name="${3}";
    local file_log_prefix="${FILE_LOG_PREFIX}";

    if [[ -n ${concrete_prof} ]]; then
        file_log_prefix="${file_log_prefix}-${concrete_prof}_cp"
    elif [[ -n ${profile_map_name} ]]; then
        file_log_prefix="${file_log_prefix}-${profile_map_name}_pnm"
    else
        file_log_prefix="${file_log_prefix}-all"
    fi;

    local -i file_index=1;
    local child_pids='';
    for file_name in ${file_name_sequence} ; do

        # Handle each file in parallel.  But log about it sequentially.
        if [[ "$(use_async_for_files)" == 'true' ]]; then
            $(handle_file_async                                     \
                "${file_name}"                                      \
                "${file_index}"                                     \
                "${file_log_prefix}-${file_index}"                  \
                "${concrete_prof}"                                  \
                "${profile_map_name}"                               \
            ) &
            child_pids+="$! "
        else
            $(handle_file               \
                "${file_name}"          \
                "${file_index}"         \
                "${concrete_prof}"      \
                "${profile_map_name}"   \
            );
        fi;

        file_index+=1
    done;
    if [[ "$(use_async_for_files)" == 'true' ]]; then
        debug "wait file ${child_pids}"
        wait "${child_pids}" || true;
        debug "ok file ${child_pids}"
        cat ${file_log_prefix}* 1>& ${OUT_LOG_STREAM}
    fi;

}

handle_file_async(){
    local input_file_name="${1}";
    local file_index="${2}";
    local file_log="${3}";
    local concrete_profile="${4}";
    local profile_map_name="${5}";
    local pid_suffix="$$-${BASH_SUBSHELL}-${BASHPID}";
    #$(notice "handles file async with PID ${pid_suffix}");
    (
        $(handle_file               \
            "${input_file_name}"    \
            "${file_index}"         \
            "${concrete_profile}"   \
            "${profile_map_name}"   \
        );
    ) 2> "${file_log}-${pid_suffix}.log";
}

handle_file(){
    local input_file_name="${1}";
    local file_index="${2}";
    local concrete_profile="${3}";
    local profile_map_name="${4}";

    $(assert_exists                         \
        "${input_file_name}"                \
        "no such file: ${input_file_name}." \
    );


    if [[ -n ${concrete_profile} ]]; then

        local profile_name=$(lower_name "${concrete_profile}");

        $(verbose_start                                         \
            "${profile_name} for ${input_file_name}@%4s"        \
        );

        $(handle_concrete_profile       \
            "${concrete_profile}"       \
            "${input_file_name}"        \
            "${file_index}"             \
        );

        $(verbose_end                                           \
            "${profile_name} for ${input_file_name}@%4s"    \
        );
    else
        $(verbose_start "${input_file_name}@%2s");
        $(handle_profile_sequence   \
            "${input_file_name}"    \
            "${file_index}"         \
            "${profile_map_name}"   \
        );
        $(verbose_end "${input_file_name}@%2s");
    fi;

}

handle_profile_sequence(){
    local input_file_name="${1}";
    local file_index="${2}";
    local profile_map_name="${3}";

    if [[ -z "${profile_map_name}" ]]; then
        profile_map_name='PROFILE_KEYS'
    fi;

    local var_name=$(echo "\${${profile_map_name}[@]}")
    local profile_list=$(eval echo "${var_name}")

    profile_list=$(                 \
        echo "${profile_list}"      \
        |sed -E 's/IS_([A-Z]+)//gi' \
    );

    profile_list=$(reorder_profile_sequence "${profile_list}");

    #profile_list=$(                 \
    #    echo "${profile_list}"      \
    #    | xargs -n1                 \
    #    | sort -u                   \
    #    | xargs                     \
    #);

    local profile_log_prefix="${PROFILE_LOG_PREFIX}-${file_index}";
    local -i profile_index=1;

    local child_pids='';
    for name in ${profile_list}; do
        if [[ "$(use_async_for_profiles)" == 'true' ]]; then
            $(handle_profile_async                                  \
                "${name}"                                           \
                "${input_file_name}"                                \
                "${profile_log_prefix}-${profile_index}"            \
            ) &
            child_pids+="$! ";
        else
            $(handle_profile "${name}" "${input_file_name}");
        fi;
        profile_index+=1
    done;
    if [[ "$(use_async_for_profiles)" == 'true' ]]; then
        debug "wait profile ${child_pids}"
        wait ${child_pids} || true;
        debug "ok profile ${child_pids}"
        cat ${profile_log_prefix}* 1>& ${OUT_LOG_STREAM}
    fi;
}


reorder_profile_sequence(){
    local profile_list="${1}";

    for name in ${profile_list}; do
        local is_abstract=$(plain_profile "${name}" 'is_abstract');
        if [[ -n "${is_abstract}" ]]; then
            profile_list=$(                                     \
                echo "${profile_list}"                          \
                | sed "s/${name}//gi"                           \
            );
        fi;
        local prev=$(plain_profile "${name}" 'after');
        if [[ -n "${prev}" ]]; then
            profile_list=$(                                     \
                echo "${profile_list}"                          \
                | sed "s/\<${name}\>//gi"                       \
            );
            profile_list=$(                                     \
                echo "${profile_list}"                          \
                | sed "s/\<${prev}\>/${prev^^} ${name}/gi"      \
            );
        fi;
    done;
    echo "${profile_list}";
}


handle_profile_async(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local profile_log="${3}";

    local pid_suffix="$$-${BASH_SUBSHELL}-${BASHPID}";

    #$(notice  "handles profile async with PID ${pid_suffix}");

    (
        $(handle_profile "${profile_name}" "${input_file_name}")
    ) 2> "${profile_log}-${pid_suffix}.log"
}

handle_profile(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local is_abstract=$(plain_profile "${profile_name}" 'is_abstract');
    local is_complex=$(plain_profile "${profile_name}" 'is_complex');

    local profile_map_name='';
    local concrete_profile_name="${profile_name}";

    ## Use is_complex=true for nested profiles
    if [[ -n "${is_complex}" ]]; then
        profile_map_name="PROFILE_${profile_name}_KEYS"
        concrete_profile_name=''
    fi;

    input_file_name=$(profile_default           \
        "${input_file_name}"                    \
        "${profile_name}"                       \
        source                                  \
    );
    input_file_name=$(profile_default           \
        "${input_file_name}"                    \
        "${profile_name}"                       \
        source                                  \
        video                                   \
    );
    input_file_name=$(profile_default           \
        "${input_file_name}"                    \
        "${profile_name}"                       \
        source                                  \
        video                                   \
        device                                  \
    );

    # Return to `handle_file_sequence`
    # for files described inside profiles.
    $(handle_file_sequence                      \
        "${input_file_name}"                    \
        "${concrete_profile_name}"              \
        "${profile_map_name}"                   \
    )

}

handle_concrete_profile(){
    local profile="${1}";
    local file_name="${2}";
    local file_index="${3}"

    $(handle_profile_depends            \
        "${profile}"                    \
        "${file_name}"                  \
        "${file_index}"                 \
    );
    $(run_concrete_profile              \
        "${profile}"                    \
        "${file_name}"                  \
    );
    $(make_profile_mark                 \
        "${profile}"                    \
        "${file_name}"                  \
        "${file_index}"                 \
    );
}

handle_profile_depends(){
    local profile="${1}";
    local file_name="${2}";
    local file_index="${3}"

    local depends_list=$(plain_profile "${profile}" 'depends');
    if [[ -n "${depends_list}" ]]; then
         for depends in ${depends_list}; do
            local prev=$(profile_mark  \
                "${depends}"             \
                "${file_name}"              \
                "${file_index}"             \
            );
            if [[ -n "${prev}" ]]; then
                while [[ ! -f "${prev}" ]]; do
                    sleep 1;
                    $(notice "NO ${prev}. Wait ... ");
                done;
                $(notice "${prev} exists");
            fi;
        done;
    fi;
}

make_profile_mark(){
    local profile="${1}";
    local file_name="${2}";
    local file_index="${3}"

    local mark=$(profile_mark      \
        "${profile}"                 \
        "${file_name}"               \
        "${file_index}"              \
    );

    $(touch "${mark}");
}

profile_mark(){
    local profile="${1}";
    local file_name="${2}";
    local file_index="${3}";
    local name=$(lower_name "${profile}");

    echo "${TMP_DIR_NAME}/${name}-${file_index}.profile";
}



# ------------------------------------------------------------
# Function for handling one profile item
# ------------------------------------------------------------

lower_name(){
    local profile_name="${1}";
    local name=$(                  \
        echo "${profile_name}"          \
        | tr '[:upper:]' '[:lower:]'    \
    );
    echo "${name}"
}

run_concrete_profile(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local lower_profile_name=$(lower_name "${profile_name}");

    verbose_start "${lower_profile_name}@%6s";
    local suffix=$(profile_default              \
        "${lower_profile_name}"                 \
        "${profile_name}"                       \
        'suffix'
    );
    local passes=$(profile_default                      \
        '1' "${profile_name}" 'passes');

    local output_format=$(profile_default               \
        'mp4' "${profile_name}" 'format');

    local extention=$(profile_default                   \
        "$output_format" "${profile_name}" 'extention');

    local output_dir_name=$(profile_default             \
        "${OUTPUT_DIR_NAME}"                            \
        "${profile_name}"                               \
        output_dir_name                                 \
    );
    local output_file_name=$(profile_default             \
        "${OUTPUT_FILE_NAME}"                            \
        "${profile_name}"                               \
        output_file_name                                 \
    );
    output_file_name=$(compute_if_empty           \
        "${output_file_name}"                           \
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
        "${profile_name}"                                       \
        "${input_file_name}"                                    \
    );
    local video_options=$(handle_video_options  \
        "${profile_name}"                       \
        "${input_file_name}"                    \
    );
    local audio_options=$(handle_audio_options  \
        "${profile_name}"                       \
        "${input_file_name}"                    \
    );
    local global_output_options=$(handle_global_output_options      \
        "${profile_name}"                                           \
        "${input_file_name}"                                        \
    );
    local output_format_options=$(handle_output_format_options      \
        "${profile_name}"                                           \
        "${input_file_name}"                                        \
        "${output_format}"                                          \
    );
    verbose_start "passes@%8s";
    for pass in $(seq 1 ${passes}); do
        local pass_options='';
        local output_pass_file_name="${output_file_name}";
        local output_audio_options="${audio_options}";
        if [[ ${passes} > 1 ]]; then
            pass_options+="-pass ${pass} "
            pass_options+="-passlogfile ${pass_log_file_prefix}";
            if [[ ${pass} <  ${passes} ]]; then
                ## Do not use `-an` due to ffmpeg bug:
                # See http://j.mp/Incomplete-MB-tree-stats-file
                # output_audio_options='-an';
                output_pass_file_name="/dev/null"
            fi;
        fi;


        log_dir_name=$(profile_default                     \
            "${LOG_DIR_NAME}"                              \
            "${profile_name}"                              \
            'log_dir_name'                                 \
        );
        local log_file_name=$(profile_default               \
            "${LOG_FILE_NAME}"                              \
            "${profile_name}"                               \
            'log_file_name'                                 \
        );
        log_file_name=$(compute_if_empty  \
            "${log_file_name}"               \
            "${input_file_name}"                \
            "${log_dir_name}"                   \
            "${suffix}-${pass}-${extention}"    \
            "ffmpeg.log"                        \
        );

        local log_callback=$(handle_log_callback  "${profile_name}");


        local -a run_args_array=(
            ${FFMPEG_BIN}
            ${global_input_options}
            "-i '${input_file_name}'"
            ${video_options}
            ${pass_options}
            ${output_audio_options}
            ${global_output_options}
            ${output_format_options}
            "-y '${output_pass_file_name}'"
        );

        if [[ "${log_file_name}" != '/dev/null' ]]; then
            if [[ -n "${log_callback}" ]]; then
                log_callback="${log_callback} | "
            fi;
            log_callback+="tee  ${log_file_name}"
            log_callback+=" 1>&${OUT_LOG_STREAM}"
            run_args_array+=("2> >(${log_callback});")
        fi;

        local run_args=$(IFS=' '; echo "${run_args_array[*]}")
        $(verbose_run "pass ${pass}@%10s"  ${run_args});

    done
    verbose_end "passes@%8s";
    verbose_end "${lower_profile_name}@%6s";
}

# ------------------------------------------------------------
# Global encoding functions
# ------------------------------------------------------------


handle_log_callback(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local -a log_callback_array=();

    local function_list=$(profile   \
        "${profile_name}"           \
        'log'                       \
        'callback'                  \
    );

    local function_list=$(profile_default   \
        "${function_list}"              \
        "${profile_name}"           \
        'log'                       \
        'callback'                  \
        'function'                  \
    );

    for callback in ${function_list}; do
        notice "callback = ${callback}"
        local name=$(sed -E  \
             's/([A-Za-z_]+)\(.+/\1/gi' <<< "$callback")
        local arg=$(sed -E  \
            's/.*\((.+)\).*/\1/gi' <<< "$callback")

        case ${name} in
            'grep')
                log_callback_array+=(                   \
                    " grep --line-buffered '${arg}' "    \
                );
                ;;
            'sed')
                log_callback_array+=(                       \
                    " sed -uE 's/.*${arg}:([^ ]+).*/\1/gi'"  \
                );
                ;;
            'frame_info')

                local reg='';
                local out='';

                # The sequential number of the frame,
                # starting from 0.
                reg+='.*n:\s*?([0-9]+)'
                out+='n:\1\t'

                # The Presentation TimeStamp of the input frame,
                # expressed as a number of time base units.
                # The time base unit depends on the filter input pad.
                reg+='.*pts:\s*?([0-9]+)'
                out+='pts:\2\t'

                # The Presentation TimeStamp of the input frame,
                # expressed as a number of seconds.
                reg+='.*pts_time:\s*?([0-9\.]+)'
                out+='pts_time:\3\t\t'

                # The position of the frame in the input stream,
                # or -1 if this information is unavailable and/or
                # meaningless (for example in case of synthetic video).
                reg+='.*pos:\s*?([0-9]+).*'
                out+='pos:\4\t'

                # The picture type of the input frame
                # ("I" for an I-frame, "P" for a P-frame,
                # "B" for a B-frame, or "?" for an unknown type).
                reg+='.*type:\s*?([IPB?]+).*'
                out+='type:\5\t'

                reg+='.*mean:\s*?\[(.+)\].*'
                out+='mean:\6 '

                reg+='.*stdev:\s*?\[(.+)\].*'
                out+='std:\7'

                log_callback_array+=(                       \
                    " grep --line-buffered  'pts_time' "    \
                    " sed -uE 's/${reg}/${out}/gi'"  \
                );
                ;;
            *)
                ;;
        esac;
    done;

    local log_callback=$(IFS='|'; echo "${log_callback_array[*]}")

    if [[ -z "${log_callback}" ]]; then
        log_callback=$(profile    \
            "${profile_name}"           \
            'log'                       \
            'callback'                  \
            'bash'
        );

    fi;


    echo "${log_callback}"
}



handle_global_input_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local options='';
    options+=$(if_exists "-threads '%s'" ${FFMPEG_THREADS});

    local start_position=$(profile_default      \
        "${FFMPEG_START}"                       \
        ${profile_name}                         \
        start                                   \
    );
    options+=$(if_exists "-ss '%s'" ${start_position});
    if [[ $(is_device ${input_file_name}) ]]; then
        local device_options=$(handle_global_device_options     \
            "${profile_name}"                                   \
            "${input_file_name}"                                \
        );
        options+="${device_options}"
    fi;
    verbose_block "global input@%8s" "${options}";
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
    options+=$(if_exists "-ss '%s'" ${start_position});
    options+=$(if_exists "-t '%s'" ${duration});
    options+=$(if_exists "-to '%s'" ${stop_position});
    if [[ -n "${options}" ]]; then
        verbose_block "global output@%8s" "${options}";
    fi;
    echo ${options};
}


handle_output_format_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local output_format="${3}";

    local options='';
    local movflags='';

    case "${output_format}" in
        'mov'|'mp4'|'ismv')  movflags+='+faststart';;
        *) ;;
    esac;

    options+=$(if_exists "-movflags '%s'" ${movflags});
    options+=$(if_exists "-f '%s'" ${output_format});
    verbose_block "format@%8s" "${options}";
    echo "${options}"
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
    local profile_name="${1}";
    local input_file_name="${2}";

    local video="$(profile ${profile_name} video)";
    if [[ "${video}" == 'undefined' ]]; then
        echo "";
        exit 0;
    fi;

    local codec_options=$(handle_video_codec_options ${profile_name});

    local framerate="$(profile ${profile_name} video framerate)";
    local rate_factor="$(profile ${profile_name} video rate_factor)";
    local bitrate="$(profile ${profile_name} video bitrate)";
    local bufsize="$(profile ${profile_name} video bufsize)";
    local maxrate="$(profile ${profile_name} video maxrate)";
    local minrate="$(profile ${profile_name} video minrate)";


    local aspect="$(profile ${profile_name} video aspect)";

    local common_options='';

    common_options+=$(if_exists "-b:v '%s'" ${bitrate});
    common_options+=$(if_exists "-crf '%s'" ${rate_factor});
    common_options+=$(if_exists "-r:v '%s'" ${framerate});
    common_options+=$(if_exists "-maxrate '%s'" ${maxrate});
    common_options+=$(if_exists "-minrate '%s'" ${minrate});
    common_options+=$(if_exists "-bufsize '%s'" ${bufsize});
    common_options+=$(if_exists "-aspect:v '%s'" ${aspect});

    # TODO: think about compatibility with progressive \ interlaced
    local pixel_format=$(profile ${profile_name} video pixel_format);
    common_options+=$(if_exists "-pix_fmt '%s'" ${pixel_format})

    local filter=$(handle_video_filter_options "${profile_name}")
    common_options+=$(if_exists "-filter:v \"%s\"" "${filter}");

    local options="${codec_options} ${common_options}";
    verbose_block "video@%8s" "${options}";
    echo ${options}
}

handle_video_filter_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local filter_options='';

    local progressive=$(profile_default     \
        'true'                              \
        "${profile_name}"                   \
        video                               \
        progressive                         \
    );
    filter_options+=$(if_exists ", yadif=1:-1:0" ${progressive});


    local width="$(profile ${profile_name} video width)";
    local height="$(profile ${profile_name} video height)";
    filter_options+=$(if_exists ", scale=%s:%s" ${width} ${height});

    local select=$(profile                  \
        "${profile_name}"                   \
        video                               \
        filter                              \
        'select'                            \
    );

    select=$(profile_default                \
        "${select}"                         \
        "${profile_name}"                   \
        video                               \
        'select'                            \
    );

    filter_options+=$(if_exists ", select='%s'" ${select});

    local scene_threshold=$(profile         \
        "${profile_name}"                   \
        video                               \
        filter                              \
        'select'                            \
        scene                               \
        threshold                           \
    );

    scene_threshold=$(profile_default       \
        "${scene_threshold}"                \
        "${profile_name}"                   \
        video                               \
        'select'                            \
        scene                               \
        threshold                           \
    );

    scene_threshold=$(profile_default       \
        "${scene_threshold}"                \
        "${profile_name}"                   \
        video                               \
        scene                               \
        threshold                           \
    );
    filter_options+=$(if_exists             \
        ", select='gt(scene,%s)'"           \
        ${scene_threshold}                  \
    );

    local showinfo=$(profile                \
        "${profile_name}"                   \
        video                               \
        filter                              \
        showinfo                            \
    );

    showinfo=$(profile_default \
        "${showinfo}"   \
        "${profile_name}" \
        video \
        showinfo \
    );
    filter_options+=$(if_exists ", showinfo" ${showinfo});

    local filter=$(profile \
        "${profile_name}" \
        video \
        filter \
    );
    filter_options+=$(if_exists ",%s" ${filter});

    filter_options=$(echo "${filter_options}" | sed -E 's/\s//gi');

    filter_options=${filter_options:1};
    echo "${filter_options}";
}


handle_video_codec_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local codec="$(profile ${profile_name} video codec)";
    if [[ "${codec}" == 'undefined' || "${codec}" == 'null' ]]; then
        echo "";
        exit 0;
    fi;

    local codec_name=$(profile_default \
        'h264' \
        ${profile_name} video codec name
    );
    local codec_options='';

    case "${codec_name}" in
        'flv')
            codec_options+=$(                                       \
                handle_video_flv_options                            \
                ${profile_name}                                     \
            );;
        'h263')
            codec_options+=$(                                       \
                handle_video_h263_options                           \
                ${profile_name}                                     \
            );;
        'h263p')
            codec_options+=$(                                       \
                handle_video_h263p_options                          \
                ${profile_name}                                     \
            );;
        'cinepak')
            codec_options+=$(                                       \
                handle_video_cinepak_options                        \
                ${profile_name}                                     \
            );;
        'mpeg4'|'xvid')
            codec_options+=$(                                       \
                handle_video_xvid_options                           \
                ${profile_name}                                     \
            );;
        'h264'|'x264')
            codec_options+=$(                                       \
                handle_video_h264_options                           \
                ${profile_name}                                     \
            );;
        'hevc'|'x265')
            codec_options+=$(                                       \
                handle_video_hevc_options                           \
                ${profile_name}                                     \
            );;
        'theora')
            codec_options+=$(                                       \
                handle_video_theora_options                         \
                ${profile_name}                                     \
            );;
        'vp8')
            codec_options+=$(                                       \
                handle_video_vp8_options                            \
                ${profile_name}                                     \
            );;
        'vp9')
            codec_options+=$(                                       \
                handle_video_vp9_options                            \
                ${profile_name}                                     \
            );;
        'snow')
            codec_options+=$(                                       \
                handle_video_snow_options                           \
                ${profile_name}                                     \
            );;
        'dirac')
            codec_options+=$(                                       \
                handle_video_dirac_options                          \
                ${profile_name}                                     \
            );;
        'jpeg2000')
            codec_options+=$(                                       \
                handle_video_jpeg2000_options                       \
                ${profile_name}                                     \
            );;
        *) ;;
    esac;

    codec_options+=$(handle_video_codec_common_options ${profile_name});
    codec_options+=$(handle_video_codec_gop_options ${profile_name});
    codec_options+=$(handle_video_codec_flags_options ${profile_name});

    echo "${codec_options}"
}

handle_video_codec_common_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_options='';

    local qscale="$(profile ${profile_name} video qscale)";
    qscale=$(profile_default        \
        "${qscale}"                 \
        "${profile_name}"           \
        video codec qscale          \
    );
    codec_options+=$(if_exists "-qscale:v '%s'" ${qscale})


    local compression_level=$(profile "${profile_name}"     \
        video codec compression_level                       \
    );
    codec_options+=$(if_exists                              \
        "-compression_level '%s'" ${compression_level}      \
    );


    echo "${codec_options}";
}


handle_video_codec_gop_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local gop_options='';
    local gop_size=$(profile "${profile_name}"  video codec gop size);
    gop_options+=$(if_exists "-g '%s'" ${gop_size});
    local min_size=$(profile "${profile_name}"  video codec gop min);
    gop_options+=$(if_exists "-keyint_min '%s'" ${min_size});
    local gop_closed=$(profile ${profile_name} video codec gop closed);
    gop_options+=$(if_exists "-flags '+cgop'" ${gop_closed})
    local no_scenecut=$(profile \
        "${profile_name}"       \
        video                   \
        codec                   \
        gop                     \
        no_scenecut             \
    );
    gop_options+=$(if_exists "-sc_threshold '0'" ${no_scenecut});
    local scenecut=$(profile    \
        "${profile_name}"       \
        video                   \
        codec                   \
        gop                     \
        scenecut                \
    );
    gop_options+=$(if_exists "-sc_threshold '%s'" ${scenecut});
    echo "${gop_options}";
}

handle_video_codec_flags_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local flag_options='';

    local flags=$(profile ${profile_name} video codec flags)
    for flag in $flags; do
        flag_options+=$(if_exists "-flags '%s'" ${flag})
    done;

    echo "$flag_options";
}

handle_video_flv_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'flashsv'";
    echo "${codec_options}"
}

handle_video_h263_options(){
    # Valid sizes for h263 are
    #   128x96, 176x144, 352x288, 704x576, and 1408x1152.
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'h263'";
    echo "${codec_options}"
}

handle_video_h263p_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'h263p'";
    echo "${codec_options}"
}

handle_video_cinepak_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'cinepak'";
    echo "${codec_options}"
}

handle_video_xvid_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'libxvid' ";
    codec_options+="-vtag 'xvid'";
    echo "${codec_options}"
}

handle_video_theora_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'libtheora'";
    echo "${codec_options}"
}

handle_video_h264_options(){
    # -profile:v = baseline, main, high, high10, high422, high444
    # See https://www.ffmpeg.org/ffmpeg-codecs.html#Video-Encoders
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';

    codec_options+="-codec:v 'libx264'";

    local codec_profile=$(profile ${profile_name} video codec profile);
    codec_options+=$(if_exists "-profile:v '%s'" ${codec_profile});

    local weightp=$(profile ${profile_name} video codec weightp);
    codec_options+=$(if_exists "-weightp '%s'" ${weightp});


    codec_options+=$(                                       \
        handle_video_h26X_options                           \
        ${profile_name}                                     \
    );


    # Constant quantization. Doesn't need to be changed.
    local qp=$(profile ${profile_name} video codec qp);
    codec_options+=$(if_exists "-qp '%s'" ${qp});

    # Constant quantization. Doesn't need to be changed.
    qp=$(profile ${profile_name} video codec quantization);
    codec_options+=$(if_exists "-qp '%s'" ${qp});

    
    # Minimum quantization. Doesn't need to be changed.
    # Recommended default: -qmin 10
    local qmin=$(profile ${profile_name} video codec qmin);
    codec_options+=$(if_exists "-qmin '%s'" ${qmin});

    # Maximum quantization. Doesn't need to be changed.
    # Recommended default: -qmax 51
    local qmax=$(profile ${profile_name} video codec qmax);
    codec_options+=$(if_exists "-qmax '%s'" ${qmax});

    # Qscale difference between P-frames and B-frames.
    local b_qfactor=$(profile ${profile_name} video codec b_qfactor);
    codec_options+=$(if_exists "-i_qfactor '%s'" ${b_qfactor});

    # Qscale difference between I-frames and P-frames.
    # Recommended: -i_qfactor 0.71
    local i_qfactor=$(profile ${profile_name} video codec i_qfactor);
    codec_options+=$(if_exists "-i_qfactor '%s'" ${i_qfactor});

    # Set max QP step. Recommended default: -qdiff 4
    local qdiff=$(profile ${profile_name} video codec qdiff);
    codec_options+=$(if_exists "-qdiff '%s'" ${qdiff});

    # QP difference between chroma and luma.
    local chromaoffset=$(profile ${profile_name} video codec chromaoffset);
    codec_options+=$(if_exists "-qdiff '%s'" ${chromaoffset});

    # CABAC is the default entropy encoder used by x264.
    # Though somewhat slower on both the decoding and encoding end,
    # it offers 10-15% improved compression on live-action sources
    # and considerably higher improvements on animated sources,
    # especially at low bitrates.
    # It is also required for the use of trellis quantization.
    # Disabling CABAC may somewhat improve decoding performance,
    # especially at high bitrates.
    # CABAC is not allowed in Baseline Profile.
    # Recommended default:
    #   -coder 1 (CABAC enabled)

    local no_cabac=$(profile ${profile_name} video codec no_cabac);
    codec_options+=$(if_exists "-coder '0'" ${no_cabac});
    local use_cabac=$(profile ${profile_name} video codec use_cabac);
    codec_options+=$(if_exists "-coder '1'" ${use_cabac});
    local coder=$(profile ${profile_name} video codec coder);
    codec_options+=$(if_exists "-coder '%s'" ${coder});


    # One of H.264's most useful features is the abillity to reference
    # frames other than the one immediately prior to the current frame.
    # This parameter lets one specify how many references can be used,
    # through a maximum of 16. Increasing the number of refs
    # increases the DPB (Decoded Picture Buffer) requirement,
    # which means hardware playback devices will often have strict
    # limits to the number of refs they can handle.
    # In live-action sources, more reference have limited use
    # beyond 4-8, but in cartoon sources up to the maximum value
    # of 16 is often useful. More reference frames require
    # more processing power because every frame is searched by
    # the motion search (except when an early skip decision is made).
    # The slowdown is especially apparent with slower motion
    # estimation methods.
    # Recommended default:
    #   -refs 6

    local refs=$(profile ${profile_name} video codec refs);
    codec_options+=$(if_exists "-refs '%s'" ${refs});

    local h26X_codec_options=$(handle_video_h26X_codec_options  \
        "${profile_name}"                                       \
    );
    codec_options+=$(if_exists "-x264opts '%s'" "${h26X_codec_options}");

    echo "${codec_options}"
}

handle_video_hevc_options(){
    # See https://www.ffmpeg.org/ffmpeg-codecs.html#Video-Encoders

    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options="-codec:v 'libx265' ";

    codec_options+=$(                                       \
        handle_video_h26X_options                           \
        ${profile_name}                                     \
    );

    local h26X_codec_options=$(handle_video_h26X_codec_options  \
        "${profile_name}"                                       \
    );
    codec_options+=$(if_exists "-x265-params '%s'" "${h26X_codec_options}");
    echo "${codec_options}"
}

handle_video_h26X_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    codec_options='';

    local preset=$(profile ${profile_name} video codec preset);
    codec_options+=$(if_exists "-preset '%s'" ${preset});

    local level=$(profile ${profile_name} video codec level);
    codec_options+=$(if_exists "-level:v '%s'" ${level});

    local bframes=$(profile ${profile_name} video codec bframes);
    codec_options+=$(if_exists "-bf '%s'" ${bframes});

    local scenecut=$(profile "${profile_name}" video codec scenecut);
    codec_options+=$(if_exists "-sc_threshold '%s'" ${scenecut});


    echo "${codec_options}"
}

handle_video_h26X_codec_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local opts_options='';


    local keyint=$(profile ${profile_name} video codec opts keyint);
    opts_options+=$(if_exists ":keyint=%s" ${keyint});

    local min_keyint=$(profile ${profile_name} video codec opts min_keyint);
    opts_options+=$(if_exists ":min-keyint=%s" ${min_keyint});

    local no_scenecut=$(profile ${profile_name} video codec opts no_scenecut);
    opts_options+=$(if_exists ":no-scenecut" ${no_scenecut});

#    local raw_opts=$(profile ${profile_name} video codec opts);
#    opts_options+=$(if_exists ":%s" ${raw_opts});

    opts_options=$(echo "${opts_options}"| sed -E 's/\s//gi');
    opts_options=${opts_options:1}

    echo "${opts_options}";
}


handle_video_vp8_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    local quality=$(profile ${profile_name} video codec quality);
    local qmin=$(profile ${profile_name} video codec qmin);
    local qmax=$(profile ${profile_name} video codec qmax);
    codec_options+="-codec:v 'libvpx'";
    codec_options+=$(if_exists "-quality '%s'" ${quality});
    codec_options+="-cpu-used '0' ";
    codec_options+=$(if_exists "-qmin '%s'" ${qmin});
    codec_options+=$(if_exists "-qmax '%s'" ${qmax});
    echo "${codec_options}";

}

handle_video_vp9_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'libvpx-vp9'";
    echo "${codec_options}";
}


handle_video_snow_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'snow'";
    echo "${codec_options}"
}

handle_video_dirac_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'dirac'";
    echo "${codec_options}";
}


handle_video_jpeg2000_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:v 'jpeg2000'";
    echo "${codec_options}";
}

# ------------------------------------------------------------
# Audio functions
# ------------------------------------------------------------

handle_audio_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local audio="$(profile ${profile_name} audio)";
    if [[ "${audio}" == 'undefined' || "${audio}" == 'null' ]]; then
        verbose_block "audio@%8s" "null";
        echo '';
        exit 0;
    fi;

    local bitrate="$(profile ${profile_name} audio bitrate)";
    local volume="$(profile ${profile_name} audio volume)";

    local samplerate="$(profile ${profile_name} audio samplerate)";

    local filter_options=$(handle_audio_filter_options  \
       "${profile_name}"                                \
       "${input_file_name}"                             \
    );
    local common_options='';

    common_options+=$(if_exists "-ar '%s'" ${samplerate});
    common_options+=$(if_exists "-b:a '%s'" ${bitrate});

    common_options+=$(handle_audio_channels_options \
        ${profile_name}                             \
        ${input_file_name}                          \
    );

    common_options+=$(if_exists "-filter:a '%s'" ${filter_options});
    local codec_options=$(handle_audio_codec_options ${profile_name});
    local options="${codec_options} ${common_options}";
    verbose_block "audio@%8s" "${options}";
    echo ${options};
}

handle_audio_channels_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local channels="$(profile ${profile_name} audio channels)";
    case "${channels}" in
        'mono')   channels='1';;
        'stereo') channels='2';;
        '5.1')    channels='6';;
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


    case "${codec_name}" in
        'mp3')
            codec_options+=$(                                       \
                handle_audio_mp3_options                            \
                ${profile_name}                                     \
            );;
        'aac')
            codec_options+=$(                                       \
                handle_audio_aac_options                            \
                ${profile_name}                                     \
            );;
        'vorbis')
            codec_options+=$(                                       \
                handle_audio_vorbis_options                         \
                ${profile_name}                                     \
            );;
        *) ;;
    esac;

    local qscale="$(profile ${profile_name} audio qscale)";
    qscale=$(profile_default                            \
        "${qscale}"                                     \
        "${profile_name}"                               \
        audio codec qscale                              \
    );

    codec_options+=$(if_exists "-qscale:a '%s'" ${qscale})

    echo "${codec_options}"

}

handle_audio_aac_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_options='';
    codec_options+="-strict 'experimental' ";
    codec_options+="-codec:a 'aac' ";
    echo "${codec_options}"
}

handle_audio_vorbis_options(){
    local profile_name="${1}";
    local input_file_name="${2}";

    local codec_options='';
    codec_options+="-codec:a 'libvorbis' ";
    echo "${codec_options}"
}

handle_audio_mp3_options(){
    local profile_name="${1}";
    local input_file_name="${2}";
    local codec_options='';
    codec_options+="-codec:a 'libmp3lame' ";
    echo "${codec_options}"
}



# ------------------------------------------------------------
# Profile fields access functions
# ------------------------------------------------------------

profile_if_exists() {
    local output_format="${1}";
    local value=$(profile ${@:2});
    if [[ -n "${value}" && "${value}" != 'undefined' ]]; then
        printf " ${output_format} " "${value}";
    fi;
}

if_exists() {
    local output_format="${1}";
    local value="${@:2}";
    for var in "${@:2}" ;do
        if [[ -z "${var}" || "${var}" == 'undefined' ]]; then
            value='undefined';
        fi;
    done
    if [[ -n "${value}" && "${value}" != 'undefined' ]]; then
        printf " ${output_format} " ${value};
    fi;
}


if_not_exists() {
    local output_format="${1}";
    local value="${@:2}";
    for var in "${@:2}" ;do
        if [[ -z "${var}" || "${var}" == 'undefined' ]]; then
            value='undefined';
        fi;
    done
    if [[ -z "${value}" || "${value}" == 'undefined' ]]; then
        printf " ${output_format} " ${value};
    fi;
}

profile_default () {
    local default="${1}";
    local value=$(profile "${@:2}");
    if [[ -z "${value}" ]]; then
        echo "${default}";
    else
        echo "${value}";
    fi;
}

profile () {
    local name="${1}";
    local value=$(plain_profile "${name}" "${@:2}")
    if [[ -z "${value}" ]]; then
        local parent_list=$(plain_profile "${name}" 'extends');
        if [[ -n "${parent_list}" ]]; then
            for parent in ${parent_list}; do
                local mb_value=$(profile "${parent}" "${@:2}");
                if [[ -n "${mb_value}" ]]; then
                    value="${mb_value}";
                fi;
            done;
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
    if [[ -z "${out_file_name}" ]]; then
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
        if [[ -z "${extention}" ]]; then
            extention="${base_file_name##*.}"
            extention=$(echo "${extention}" \
                | tr '[:upper:]' '[:lower:]');
        fi;
        if [[ -n "${initial_dir_name}" ]]; then
            parent_dir_name=$(dirname "${initial_dir_name}");
            base_dir_name=$(basename "${initial_dir_name}");
            local out_dir_name="${parent_dir_name}/${base_dir_name}";
            $(create_directory 'any' "${out_dir_name}");
            base_name="${out_dir_name}/${base_name}";
        fi;
        out_file_name="${base_name}.${extention}"
        if [[ -n "${suffix}" ]]; then
            out_file_name="${base_name}-${suffix}.${extention}"
        fi;
    fi;
    echo "${out_file_name}";
}

start_up (){
    $(create_directory 'tmp' "${TMP_DIR_NAME}"    'at start up.');
    $(create_directory 'log' "${LOG_DIR_NAME}"    'at start up.');
    $(create_directory 'out' "${OUTPUT_DIR_NAME}" 'at start up.');
}

create_directory() {
    local type="${1}";
    local name="${2}";
    local comment="${3}";
    if [[ -n "${name}" ]]; then
        if [[ -e "${name}" && ! -d "${name}" ]]; then
            error "${name} is a file\n";
            exit_fail;
        elif [[ ! -e "${name}"  ]]; then
            notice "creates ${type} directory '${name}' ${comment}";
            mkdir -p "${name}";
        fi;
    fi;
}


use_async_for_files(){
    local default="${ASYNC_FILES_DEFAULT}";
    if [[                                       \
        "${SELF_IS_ASYNC}" == 'true'            \
        || "${SELF_IS_ASYNC_FILES}" == 'true'   \
    ]]; then
        echo 'true';
    elif  [[                                     \
        "${SELF_NO_ASYNC}" == 'true'            \
        || "${SELF_NO_ASYNC_FILES}" == 'true'   \
    ]]; then
        echo 'false';
    else
        echo "${default}";
    fi;
}

use_async_for_profiles(){
    local default="${ASYNC_PROFILES_DEFAULT}";
    if [[                                       \
        "${SELF_IS_ASYNC}" == 'true'            \
        || "${SELF_IS_ASYNC_PROFILES}" == 'true'   \
    ]]; then
        echo 'true';
    elif  [[                                     \
        "${SELF_NO_ASYNC}" == 'true'            \
        || "${SELF_NO_ASYNC_PROFILES}" == 'true'   \
    ]]; then
        echo 'false';
    else
        echo "${default}";
    fi;
}


clean_up (){
    if [[ -d "${TMP_DIR_BASE_NAME}" ]]; then
        notice "deletes directory ${TMP_DIR_BASE_NAME}"
        rm -rf "${TMP_DIR_BASE_NAME}";
    fi;
}

assert_not_empty () {
    local out_file_name="${1}";
    local message="${2}";
    if [[ -z "${out_file_name}" ]]; then
        wrong_usage "${message}";
    fi;
}

assert_exists () {
    local file_name="${1}";
    local message="${2}";
    if [[ $(is_device ${file_name}) ]]; then
        notice "uses display '${file_name}' as a file name"
    elif [[ "${file_name}" == "${FROM_CONFIG_FILE_NAME}" ]]; then
        notice "gets file names from config";
    elif [[ ! -f "${file_name}" ]]; then
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
            'i:o:f:c:O:P:F:hvqd'                    \
        --long                                      \
            'input:,                                \
            output:,                                \
            config:,                                \
            output-dir:,                            \
            pass-log-dir:,                          \
            ffmpeg-log-dir:,                        \
            ffmpeg-log:,
            help,                                   \
            verbose,                                \
            quiet,                                  \
            async,                                  \
            async-files,                            \
            async-profiles,                         \
            no-async,                               \
            no-async-files,                         \
            no-async-profiles,                      \
            dry-run'                                \
        -n "$0"                                     \
        -- "${@}");
    eval set -- ${OPTIONS};

    while [[ -n ${OPTIONS} ]]; do
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
            -F|--ffmpeg-log-dir)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        LOG_DIR_NAME=${2};
                        shift 2;;
                esac;;
            -f|--ffmpeg-log)
                case "${2}" in
                    '')
                        shift 1;;
                    *)
                        LOG_FILE_NAME=${2};
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
            --async)
                SELF_IS_ASYNC='true';
                shift;;
            --async-files)
                SELF_IS_ASYNC_FILES='true';
                shift;;
            --async-profiles)
                SELF_NO_ASYNC_PROFILES='true';
                shift;;
            --no-async)
                SELF_NO_ASYNC='true';
                shift;;
            --no-async-files)
                SELF_NO_ASYNC_FILES='true';
                shift;;
            --no-async-profiles)
                SELF_NO_ASYNC_PROFILES='true';
                shift;;
            '--'|'')
                shift 1;
                INPUT_FILE_NAME_LIST+="$@"
                break;;
            *) wrong_usage "Unknown parameter '${1}'.";;
        esac;
    done;
    declare -rg VERBOSE;
    declare -rg CONFIG_FILE_NAME;
    declare -rg OUTPUT_DIR_NAME;
    declare -rg OUTPUT_FILE_NAME;
    declare -rg LOG_DIR_NAME;
    declare -rg LOG_FILE_NAME;
    declare -rg PASS_LOG_DIR_NAME;
    if [[ -z "${INPUT_FILE_NAME_LIST}" ]]; then
        INPUT_FILE_NAME_LIST="${FROM_CONFIG_FILE_NAME}"
        FROM_CONFIG_FLAG='true';
    fi;
    declare -rg INPUT_FILE_NAME_LIST;
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
                printf("declare -ga %sKEYS; ", vn, vnn);
            }
            varray[vn] = 1
            if (!((vn,vnn) in varray)){
                printf("%sMAP[\"%s\"]=\"%s\"; ", vn, vnn, $3);
                printf("%sKEYS+=(\"%s\"); ", vn,  vnn);

            }
            varray[vn,vnn] = 1
        }
        printf("readonly %s%s=\"%s\"; ", vn, tail, $3);
    }' ;
}

# ------------------------------------------------------------
# Printing functions
# ------------------------------------------------------------

declare LOG_OFFSET='';

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
    exit_ok;
}

wrong_usage(){
    usage;
    error "${@}";
    exit_fail;
}

verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        printf "${@}\n" 1>& ${OUT_LOG_STREAM};
    fi
}

verbose_offset (){
    LOG_OFFSET="${1}";
    verbose "${1}${2}";
}

verbose_inside (){
    $(verbose_offset "${1}  "   "${2}");
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
    local value="${@:2}";
    value=$(strip_string "${value}");
    verbose_start "${string}"
    verbose_inside "${offset}"\
    "${COLOR_BOLD}${COLOR_DARK_CYAN}${value}${COLOR_OFF}";
    verbose_end "${string}";
}

strip_string(){
    local value=${1};
    value=$(echo "${value}" \
        | sed -E 's/\s+/ /gi' \
        | sed -E 's/^\s+//gi' \
    );
    echo "${value}";
}

verbose_run (){
    local string="${1}";
    local offset='';
    local delimiter='@';
    local offset=$(awk -F "$delimiter" '{print $2}' <<< "$string");
    local value="${@:2}";

    local COLOR_ON="${COLOR_BOLD}${COLOR_LIGHT_YELLOW}"
    verbose_start "${string}";
    local v_value=$(echo "${value}" | sed -E 's/\\/\\\\/gi' );

    $(verbose_inside                        \
        "${offset}"                         \
        "${COLOR_ON}${v_value}${COLOR_OFF}"   \
    );
    if [[ "${DRY_RUN}" == "false" ]]; then
        if [[ "${VERBOSE}" == "true" ]]; then
            $(eval "${value}");
        fi;
        if [[ "${VERBOSE}" == "false" ]]; then
            $(eval "${value}") 2> /dev/null
     fi
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

signal () {
    info_print  'SIGNAL'\
                "${BG_COLOR_DARK_RED}"\
                "${COLOR_DARK_YELLOW}"\
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
                "${COLOR_DIM}${COLOR_DARK_CYAN}"\
                "${@}"
}

debug() {
    local NS=$(($(date +%s%N)-${START_TIME_NS}))
    local MS=$((${NS}/1000000))
    info_print  "DEBUG ${MS}"\
                "${BG_COLOR_DARK_GREEN}"\
                "${COLOR_DARK_BLACK}"\
                "${COLOR_DIM}${COLOR_DARK_GREEN}"\
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
    printf "${LABEL} ${WHERE}${MESSAGE}\n" \
        1>& ${OUT_LOG_STREAM};
}

exit_signal () {
  local signum="${1}";
  local parent_lineno="$2";
  local message="$3";
  local code="${4:-$((${signum}+128))}";
  local sigspec=$(kill -l ${signum});

  if [[ -n "$message" ]] ; then
    error "gets signal ${sigspec} (${signum})"       \
        " at line ${parent_lineno}: ${message};"    \
        " exiting by with status ${code}"
  else
    error "gets signal ${sigspec} (${signum})"       \
        "at line ${parent_lineno};"                 \
        "exiting with status ${code}"
  fi;
  sleep 1;
  exit "${code}";
}


exit_fatal () {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-4}"
  if [[ -n "$message" ]] ; then
    fail "fails at line ${parent_lineno}: ${message}."
  else
    fail "fails at line ${parent_lineno}."
  fi
  exit "${code}";
}

exit_ok (){
    kill -s USR1 ${SCRIPT_PID};
    exit 0;
}

exit_fail (){
    local sign=${1:-USR2}
    kill -s "${sign}" ${SCRIPT_PID};
    exit 0;
}

trap_signal() {
    for sig  in $@; do
        trap "exit_signal ${sig} ${LINENO}" ${sig}
    done
}

# ------------------------------------------------------------
# Main function call.
# ------------------------------------------------------------
#
trap_signal 2 3 4 5 6 8 9 10 11 12 13 15 30 31

trap 'exit_fatal ${LINENO} || true' ERR;
trap 'exit 0' USR1;
trap 'exit 3' USR2;


main "${@}";
