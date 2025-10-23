#!/usr/bin/env bash

# Utility functions for CI logging and grouping.
# This file is intended to be sourced from other scripts.

# Detect if we are running on GitHub Actions
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  IS_GITHUB_ACTIONS=true
else
  IS_GITHUB_ACTIONS=false
fi

# Get current timestamp in format HH:MM:SS.mmm
get_timestamp() {
  date +"%T.%3N"
}

log_notice() {
  if $IS_GITHUB_ACTIONS; then
    echo "[$(get_timestamp)] ::notice::${1}"
  else
    echo "[$(get_timestamp)] [notice] ${1}"
  fi
}

log_warning() {
  if $IS_GITHUB_ACTIONS; then
    echo "[$(get_timestamp)] ::warning::${1}"
  else
    echo "[$(get_timestamp)] [warning] ${1}"
  fi
}

log_error() {
  if $IS_GITHUB_ACTIONS; then
    echo "[$(get_timestamp)] ::error::${1}"    
  else                      
    echo "[$(get_timestamp)] [error] ${1}"     
  fi                        
}                           
                            
begin_group() {             
  local title="$1"          
  if $IS_GITHUB_ACTIONS; then
    echo "[$(get_timestamp)] ::group::${title}"
  else                      
    echo "[$(get_timestamp)]"                    
    echo "[$(get_timestamp)] == ${title} =="
  fi                        
}                           
                            
end_group() {               
  if $IS_GITHUB_ACTIONS; then
    echo "[$(get_timestamp)] ::endgroup::"     
  fi                        
}
