#!/bin/bash
set -euo pipefail

# Helpers
# Color codes for logging levels
RESET='\033[0m'
INFO_COLOR='\033[0m'        # Default color
SUCCESS_COLOR='\033[0;32m'  # Green for success
ERROR_COLOR='\033[0;31m'    # Red for errors
DEBUG_COLOR='\033[0;90m'    # Dark gray for debug info
CYAN_COLOR='\033[0;36m'    # Cyan for general info

# Logging functions
log_info() {
    echo -e "${INFO_COLOR}$1${RESET}"
}

log_success() {
    echo -e "${SUCCESS_COLOR}$1${RESET}" 
}

log_error() {
    echo -e "${ERROR_COLOR}$1${RESET}"
}

log_debug() {
    echo -e "${DEBUG_COLOR}$1${RESET}"
}

# Script

EXIT_CODE=0

RESULT_PATH="${1}"
EXPANDED_RESULT_PATH=$(realpath "$RESULT_PATH")

log_info "+==============+"
log_info "| TEST SUMMARY |"
log_info "+==============+"
log_info ""
log_info "Creating test summary from result at path: $EXPANDED_RESULT_PATH"
log_info ""

if [ ! -d "$EXPANDED_RESULT_PATH" ]; then
    log_error "Result path '$EXPANDED_RESULT_PATH' does not exist"
    exit 1
fi

# The `xcresulttool` requires different options based on the version of Xcode.
xcresulttool_version=$(xcrun xcresulttool version | grep -oE '[0-9]+\.[0-9]+' | head -1)
major_version=$(echo "$xcresulttool_version" | cut -d '.' -f 1)
minor_version=$(echo "$xcresulttool_version" | cut -d '.' -f 2)
log_debug "xcresulttool version: $major_version.$minor_version" 

if (( major_version >= 3 )) && (( minor_version >= 53 )); then # Xcode 16.0
    TEST_REPORT_JSON=$(xcrun xcresulttool get test-report --path "$EXPANDED_RESULT_PATH" --legacy --format json)
elif (( major_version >= 3 )) && (( minor_version >= 49 )); then # Xcode 15.4
    TEST_REPORT_JSON=$(xcrun xcresulttool get --path "$EXPANDED_RESULT_PATH" --format json)
else 
    TEST_REPORT_JSON=$(xcrun xcresulttool get --path "$EXPANDED_RESULT_PATH" --format json)
fi

ACTION_RESULTS=$(echo "$TEST_REPORT_JSON" | jq '.actions._values[].actionResult')
STATUS=$(echo "$ACTION_RESULTS" | jq -r '.status._value')

# Print failed tests
if [ "$STATUS" == "failed" ]; then
    log_info "Test Failures:"
    FAILURE_SUMMARIES=$(echo "$TEST_REPORT_JSON" | jq -c '.issues.testFailureSummaries._values[]')

    # Process each failure to print details
    echo "$FAILURE_SUMMARIES" | while read -r FAILURE_SUMMARY; do
        TEST_CASE_NAME=$(echo "$FAILURE_SUMMARY" | jq -r '.testCaseName._value')
        MESSAGE=$(echo "$FAILURE_SUMMARY" | jq -r '.message._value')
        LOCATION=$(echo "$FAILURE_SUMMARY" | jq -r '.documentLocationInCreatingWorkspace.url._value' | sed 's/file:\/\///')
        FILE_PATH=${LOCATION%%#*}
        
        # Extract line number from location URL
        STARTING_LINE_NUM=$(echo "$LOCATION" | grep -o 'StartingLineNumber=[0-9]*' | cut -d= -f2)
        ENDING_LINE_NUM=$(echo "$LOCATION" | grep -o 'EndingLineNumber=[0-9]*' | cut -d= -f2)
        
        # Print failure details
        log_error "  $TEST_CASE_NAME"
        log_error "  $MESSAGE"
        log_info "  Location: ${CYAN_COLOR}$FILE_PATH:$STARTING_LINE_NUM-$ENDING_LINE_NUM${RESET}"
        
        # If the file exists, print the surrounding code
        if [ -f "$FILE_PATH" ]; then
            CODE_SNIPPET=$(sed -n "$((STARTING_LINE_NUM-2)),$((ENDING_LINE_NUM+2))p" "$FILE_PATH" | sed 's/^/  /')
            log_debug "  \`\`\`\n${DEBUG_COLOR}$CODE_SNIPPET${RESET}\n  \`\`\`"
        fi
        log_info ""
    done

    # Print the list of failing tests
    log_info "Failing tests:"
    log_info "$(echo "$FAILURE_SUMMARIES" | jq -r '"  " + .testCaseName._value' | sort | uniq)"
    log_info ""
    
    # Print the status
    log_error "** TEST EXECUTION FAILED **"
    log_info ""

    EXIT_CODE=1
else
    # Print the status
    log_success "** TEST EXECUTION PASSED - $STATUS**"
    log_info ""
fi

# Print metrics
EXECUTED_TESTS=$(echo "$ACTION_RESULTS" | jq -r '.metrics.testsCount._value')
FAILED_TESTS=$(echo "$ACTION_RESULTS" | jq -r '.metrics.testsFailedCount._value | if . == null then 0 else . end')
SKIPPED_TESTS=$(echo "$ACTION_RESULTS" | jq -r '.metrics.testsSkippedCount._value | if . == null then 0 else . end')

log_info "Executed: $EXECUTED_TESTS, with $FAILED_TESTS failures ($SKIPPED_TESTS skipped)"

exit $EXIT_CODE
