#!/usr/bin/env bash

## Do dirty thing: Copy actual result to expected result.

## Test configuration — initial constants for test running:

readonly TESTS_PATH='./examples';
readonly TEST_CONFIG_PATTERN='*.test-config.yaml';

## Computed constants for test running:

readonly TESTS_FPATH=$(readlink -f "${TESTS_PATH}");
readonly TEST_CONFIG_FIND_ARGS="-name ${TEST_CONFIG_PATTERN}" ;

readonly EXP_EXT='expected';
readonly ACT_EXT='actual';
readonly RSLT_DNAME='test-results';


tests_dirty_fix () {

    readonly CONFIG_PATH_LIST=$(                            \
        find ${TESTS_FPATH}                                 \
            -type f                                         \
            ${TEST_CONFIG_FIND_ARGS}                        \
        | sort                                              \
    );
    readonly TEST_COUINT=$(echo ${CONFIG_PATH_LIST} | wc -w);
    
    for CONFIG_PATH in ${CONFIG_PATH_LIST}; do
        echo "dirty fix '${CONFIG_PATH}';";
        local CONFIG_FPATH=$(readlink -f "${CONFIG_PATH}");
        local TEST_BASE_NAME=$(basename "${CONFIG_FPATH}");
        local TEST_DPATH=$(dirname "${CONFIG_FPATH}");
        local TEST_NAME="${TEST_BASE_NAME%.*.*}";
        local RSLT_DPATH="${TEST_DPATH}/${RSLT_DNAME}";

        # Set paths for files.
        local EXP_FPATH="${TEST_DPATH}/${TEST_NAME}.${EXP_EXT}.yaml";
        local ACT_FPATH="${RSLT_DPATH}/${TEST_NAME}.${ACT_EXT}.yaml";

        
        cp "${ACT_FPATH}" "${EXPCTD_FPATH}";

    done;
    echo "dirty fix ok";
}

tests_dirty_fix;
