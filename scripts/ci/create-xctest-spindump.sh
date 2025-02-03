#!/bin/bash

echo "Detecting xctest process..."
XCTEST_PID=$(pgrep -f xctest || echo "")

if [[ -n "$XCTEST_PID" ]]; then
    echo "Capturing spindump for xctest PID: $XCTEST_PID"
    sudo spindump "$XCTEST_PID" -file spindump.txt
else
    echo "No xctest process found. Capturing system-wide spindump."
    sudo spindump -file spindump.txt
fi
