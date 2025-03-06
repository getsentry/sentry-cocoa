#!/bin/bash

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <known_warnings_file> <build_log_file> [accept_new_baseline]"
    exit 1
fi

known_warnings_file="$1"
build_log_file="$2"
accept_new_baseline=false
if [ "$3" == "accept_new_baseline" ]; then
    accept_new_baseline=true
fi

known_warnings=()
while IFS= read -r line; do
    known_warnings+=("$line")
done < "$known_warnings_file"
unknown_is_known_warning=false

build_log_warnings=$(grep "warning:" "$build_log_file")

extracted_warnings=()
while IFS= read -r line; do
    extracted_warning=$(echo "$line" | cut -d' ' -f2-)
    extracted_warnings+=("$extracted_warning")
done < <(echo "$build_log_warnings")

for line in "${extracted_warnings[@]}"; do
    is_known_warning=false
    for known_warning in "${known_warnings[@]}"; do
        if [[ "$line" == "$known_warning" ]]; then
            echo "Found known warning: $line"
            is_known_warning=true
            break
        fi
    done
    if ! $is_known_warning; then
        echo "Unknown warning found: $line"
        unknown_is_known_warning=true
    fi
    if [ "$accept_new_baseline" == "true" ]; then
        known_warnings+=("$line")
    fi
done

if [ "$accept_new_baseline" == "true" ]; then
    echo "Updating known warnings file..."
    printf "%s\n" "${known_warnings[@]}" | sort -u | sed '/^$/d' > "$known_warnings_file"
fi

if $unknown_is_known_warning; then
    exit 1
fi
