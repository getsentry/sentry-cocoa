#!/bin/bash

# Finds the x amount of slowest test cases in the raw-test-output.log file.
# Logic copied from https://stanislaw.github.io/2016/08/04/how-to-find-the-slowest-xctest.html.

RAW_TEST_OUTPUT_LOG=${1:-raw-test-output.log}
NUMBER_OF_SLOWEST_TEST="${2:-10}"

echo "The $NUMBER_OF_SLOWEST_TEST slowest test cases:" 
cat $RAW_TEST_OUTPUT_LOG | grep 'Test\ Case.*seconds' | awk -F '[()]' '{print $2 " -> " $1}' | sort -rn | head -$NUMBER_OF_SLOWEST_TEST
