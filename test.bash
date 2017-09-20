#!/usr/bin/env bash

## Just run `bash ./test.bash`
## It calls bulk_video_converter.bash 
## with YAML-configurations from examples-folder. 
## It uses all files with suffix .test-config.yaml 
## to generate script output and compare 
## actual output with the expected result. 
## Tests work without running real video handling. 
## Only generated FFMpeg options are tested.


## Test configuration — initial constants for test running:

readonly SCRIPT_PATH="./bulk_video_converter.bash";
readonly TESTS_PATH='./examples';
readonly TEST_CONFIG_PATTERN='*.test-config.yaml';

## Computed constants for test running:

readonly SCRIPT_FPATH=$(readlink -f "${SCRIPT_PATH}");
readonly TESTS_FPATH=$(readlink -f "${TESTS_PATH}");
readonly TEST_CONFIG_FIND_ARGS="-name ${TEST_CONFIG_PATTERN}" ;

## Fixtures:

readonly INPUT_FILE_PATH_FIXTURE='input/files/are/from/config';
readonly START_TIME_STRING_FIXTURE="1970-01-01_01-01-01-00";
readonly RANDOM_STRING_FIXTURE="R1Nd0m";  
readonly VIDEO_OUTPUT_DIR_FIXTURE='/tmp/video/output/dir/fixture';
readonly FFMPEG_LOG_DIR_FIXTURE='/tmp/ffmpeg/log/dir/fixture';
readonly PASS_LOG_DIR_FIXTURE='/tmp/pass/log/dir/fixture';


run_tests () {
    print_help "test script ${SCRIPT_PATH};";    
    
    readonly CONFIG_PATH_LIST=$(                            \
        find ${TESTS_FPATH}                                 \
            -type f                                         \
            ${TEST_CONFIG_FIND_ARGS}                        \
        | sort                                              \
    );
    readonly TEST_CNT=$(echo ${CONFIG_PATH_LIST} | wc -w);
    
    notice "${TEST_CNT} tests found;";
    
    local -i TEST_NUM=1;
    
    for CONFIG_PATH in ${CONFIG_PATH_LIST}; do
        local TEST_ITER="${TEST_NUM} from ${TEST_CNT}";
        notice "prepare test ${TEST_ITER} with '${CONFIG_PATH}';";
        debug "use config file path '${CONFIG_PATH}';";
        local CONFIG_FPATH=$(readlink -f "${CONFIG_PATH}");
        debug "with config file full path '${CONFIG_FPATH}';";
        local TEST_BASE_NAME=$(basename "${CONFIG_FPATH}");
        debug "with test base name '${TEST_BASE_NAME}';";
        local TEST_DPATH=$(dirname "${CONFIG_FPATH}");
        debug "with test path'${TEST_DPATH}';";
        local TEST_NAME="${TEST_BASE_NAME%.*.*}"
        local TEST_ID="'${TEST_NAME}' (${TEST_ITER})";
        action "run test ${TEST_ID};";
        local RESULT_DPATH="${TEST_DPATH}/result.d";
        debug "with result path '${RESULT_DPATH}';";
        debug "=> so create dir '${RESULT_DPATH}';";
        mkdir -p "${RESULT_DPATH}";
        
        # Set paths for files.
        local EXPCTD_FPATH="${TEST_DPATH}/${TEST_NAME}.expected.yaml";
        debug "where expected result file path is '${EXPCTD_FPATH}';";
        local RAW_FPATH="${RESULT_DPATH}/${TEST_NAME}.raw.yaml";
        debug "where raw result file path is '${RAW_FPATH}';";
        local ACTL_FPATH="${RESULT_DPATH}/${TEST_NAME}.actual.yaml";
        debug "where actual result file path is '${ACTL_FPATH}';";
        local DIFF_FPATH="${RESULT_DPATH}/${TEST_NAME}.diff";
        debug "where diff file path is '${DIFF_FPATH}';";

        notice 'set $ENV and run script ...';
        debug "use ENV:"
        debug " with START_TIME_STRING='${START_TIME_STRING_FIXTURE}';";
        debug " with RANDOM_STRING='${RANDOM_STRING_FIXTURE}';";
        debug "use --input='${INPUT_FILE_PATH_FIXTURE}';";
        debug "use --config='${CONFIG_FPATH}';";
        debug "use --output-dir='${VIDEO_OUTPUT_DIR_FIXTURE}';";
        debug "use --ffmpeg-log-dir='${FFMPEG_LOG_DIR_FIXTURE}';";
        debug "use --pass-log-dir='${PASS_LOG_DIR_FIXTURE}';";
        debug "use --dry-run;";
        debug "use --no-async;";        
        debug "and store script result to ${RAW_FPATH}";
        
        # Set ENV and run script
        START_TIME_STRING="${START_TIME_STRING_FIXTURE}"    \
        RANDOM_STRING="${RANDOM_STRING_FIXTURE}"            \
        "${SCRIPT_FPATH}"                                   \
            --config "${CONFIG_FPATH}"                      \
            --input "${INPUT_FILE_PATH_FIXTURE}"            \
            --output-dir "${VIDEO_OUTPUT_DIR_FIXTURE}"      \
            --ffmpeg-log-dir "${FFMPEG_LOG_DIR_FIXTURE}"     \
            --pass-log-dir "${PASS_LOG_DIR_FIXTURE}"        \
            --dry-run                                       \
            --no-async                                      \
            2> "${RAW_FPATH}";
        notice 'script is ok';
        
        notice 'build fine yaml ... ';
        debug "delete commnet from '${RAW_FPATH}';";
        debug "and store result to '${ACTL_FPATH}';";
        grep -v '#' "${RAW_FPATH}" > "${ACTL_FPATH}";
        notice 'yaml is built';
    
        notice 'build test diff ...';
        debug 'use diff -u expected/file actual/file;';
        debug "expected/file is '${EXPCTD_FPATH}';"
        debug "actual/file   is '${ACTL_FPATH}';"
        debug 'to make diff empty use:';
        debug "cp '${ACTL_FPATH}' '${EXPCTD_FPATH}';"
        diff -u "${EXPCTD_FPATH}" "${ACTL_FPATH}" 1> "${DIFF_FPATH}"\
        && success "test ${TEST_ID} is ok"     \
        || fail "test ${TEST_ID} is failed";
    
        TEST_NUM+=1;
    done;
    happy_end "all tests (${TEST_CNT}) is ok";
}

## Utils:

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

readonly COLOR_START="${COLOR_LIGHT_MAGENTA}";
readonly COLOR_ERROR="${COLOR_LIGHT_RED}";
readonly COLOR_ACTION="${COLOR_DARK_BLACK}${BG_COLOR_LIGHT_CYAN} ";
readonly COLOR_NOTICE="${COLOR_LIGHT_CYAN}";
readonly COLOR_DEBUG="${COLOR_DARK_GREEN}";
readonly COLOR_FINAL="${COLOR_LIGHT_GREEN}";
readonly COLOR_DATE="${COLOR_DIM}";
readonly COLOR_DONE="${COLOR_DARK_BLACK}${BG_COLOR_DARK_GREEN} ";
readonly COLOR_HELP="${COLOR_DARK_BLACK}${BG_COLOR_DARK_YELLOW} ";

fail () {
    echo -e "${COLOR_START}# ${COLOR_ERROR}${@}${COLOR_OFF}";
    exit 1;
}

happy_end () {
    echo -e  "${COLOR_START}# ${COLOR_FINAL}${@} ${COLOR_OFF}";
}

success () {
    log "${COLOR_DONE}${@}${COLOR_OFF}";
}

action () {
    log "${COLOR_ACTION}${@}${COLOR_OFF}";
}

notice () {
    log "${COLOR_NOTICE}  ${@}${COLOR_OFF}";
}

debug () {
    log "${COLOR_DEBUG}    ${@}${COLOR_OFF}";
}

print_help () {
    echo -e "${COLOR_START}# ${COLOR_HELP}${@}${COLOR_OFF}";
}

log () {
    local _date=$(date '+%Y.%m.%d %H:%M:%S');
    local date="${COLOR_DATE}[${_date}]${COLOR_OFF}";
    local start="${COLOR_START}#${COLOR_OFF} ";
    
    echo -e "${start} ${date} ${@}";
}

run_tests;
