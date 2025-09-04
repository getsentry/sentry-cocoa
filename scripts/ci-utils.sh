#!/usr/bin/env bash

# Utility functions for CI logging and grouping.
# This file is intended to be sourced from other scripts.

# Detect if we are running on GitHub Actions
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  IS_GITHUB_ACTIONS=true
else
  IS_GITHUB_ACTIONS=false
fi

log_notice() {
  if $IS_GITHUB_ACTIONS; then
    echo "::notice::${1}"
  else
    echo "[notice] ${1}"
  fi
}

log_warning() {
  if $IS_GITHUB_ACTIONS; then
    echo "::warning::${1}"
  else
    echo "[warning] ${1}"
  fi
}

log_error() {
  if $IS_GITHUB_ACTIONS; then
    echo "::error::${1}"    
  else                      
    echo "[error] ${1}"     
  fi                        
}   

log_duration() {
  local command="$1"
  
  local start_time end_time duration
  start_time=$(date +%s)
  
  # Execute the command
  eval "$command"
  local exit_code=$?
  
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # Return only the duration in seconds
  echo "$duration"
  
  return $exit_code
}

                            
begin_group() {             
  local title="$1"          
  if $IS_GITHUB_ACTIONS; then
    echo "::group::${title}"
  else                      
    echo                    
    echo "== ${title} =="
  fi                        
}                           
                            
end_group() {               
  if $IS_GITHUB_ACTIONS; then
    echo "::endgroup::"     
  fi                        
}
