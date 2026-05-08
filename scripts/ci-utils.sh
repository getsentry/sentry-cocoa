#!/usr/bin/env bash

# Utility functions for CI logging and grouping.
# This file is intended to be sourced from other scripts.
#
# Wraps all GitHub Actions workflow commands that use the ::command:: syntax.
# Specification: https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions
#
# Available functions:
#   log_info <message>           — echo {message}
#   log_debug <message>          — ::debug::{message}
#   log_notice <message>         — ::notice::{message}
#   log_warning <message>        — ::warning::{message}
#   log_error <message>          — ::error::{message}
#   begin_group <title>          — ::group::{title}
#   end_group                    — ::endgroup::
#   mask_value <value>           — ::add-mask::{value}
#   stop_commands <token>        — ::stop-commands::{token}
#   resume_commands <token>      — ::{token}::
#   set_command_echo <on|off>    — ::echo::{on|off}
#   set_env <name> <value>       — writes to $GITHUB_ENV
#   set_output <name> <value>    — writes to $GITHUB_OUTPUT
#   append_summary <markdown>    — writes to $GITHUB_STEP_SUMMARY

# Detect if we are running on GitHub Actions
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  IS_GITHUB_ACTIONS=true
else
  IS_GITHUB_ACTIONS=false
fi

# Get current timestamp in format HH:MM:SS
get_timestamp() {
  date +"%T"
}

# Print an info message to the log.
# This is a wrapper around the `echo` command for consistency.
log_info() {
  echo "$*"
}

# Print a debug message to the log.
# On GitHub Actions the message is only visible when the ACTIONS_STEP_DEBUG secret is set to true.
# Syntax: ::debug::{message}
log_debug() {
  if $IS_GITHUB_ACTIONS; then
    echo "::debug::[$(get_timestamp)] ${1}"
  else
    echo "[debug] [$(get_timestamp)] ${1}"
  fi
}

# Create a notice annotation and print the message to the log.
# On GitHub Actions the annotation can optionally be associated with a file via
# additional parameters (file, line, endLine, col, endColumn, title) — this
# wrapper only emits the message form.
# Syntax: ::notice file={name},line={line},endLine={endLine},title={title}::{message}
log_notice() {
  if $IS_GITHUB_ACTIONS; then
    echo "::notice::[$(get_timestamp)] ${1}"
  else
    echo "[notice] [$(get_timestamp)] ${1}"
  fi
}

# Create a warning annotation and print the message to the log.
# On GitHub Actions the annotation can optionally be associated with a file via
# additional parameters (file, line, endLine, col, endColumn, title) — this
# wrapper only emits the message form.
# Syntax: ::warning file={name},line={line},endLine={endLine},title={title}::{message}
log_warning() {
  if $IS_GITHUB_ACTIONS; then
    echo "::warning::[$(get_timestamp)] ${1}"
  else
    echo "[warning] [$(get_timestamp)] ${1}"
  fi
}

# Create an error annotation and print the message to the log.
# On GitHub Actions the annotation can optionally be associated with a file via
# additional parameters (file, line, endLine, col, endColumn, title) — this
# wrapper only emits the message form.
# Syntax: ::error file={name},line={line},endLine={endLine},title={title}::{message}
log_error() {
  if $IS_GITHUB_ACTIONS; then
    echo "::error::[$(get_timestamp)] ${1}"
  else
    echo "[error] [$(get_timestamp)] ${1}"
  fi
}

# Start an expandable group in the log. Everything printed between begin_group
# and end_group is nested inside a collapsible section.
# Syntax: ::group::{title}
begin_group() {
  local title="$1"
  if $IS_GITHUB_ACTIONS; then
    echo "::group::${title}"
  else
    echo
    echo "== ${title} =="
  fi
}

# End the current expandable group.
# Syntax: ::endgroup::
end_group() {
  if $IS_GITHUB_ACTIONS; then
    echo "::endgroup::"
  fi
}

# Mask a value so it is replaced with *** in the log. Each masked word
# separated by whitespace is redacted independently. Once masked the value is
# treated as a secret on the runner.
# Syntax: ::add-mask::{value}
mask_value() {
  if $IS_GITHUB_ACTIONS; then
    echo "::add-mask::${1}"
  fi
}

# Stop processing any workflow commands. Anything printed after this call is
# logged verbatim — no :: commands are interpreted until resume_commands is
# called with the same token. The token should be randomly generated and unique
# per run to avoid collisions.
# Syntax: ::stop-commands::{endtoken}
#
# Example:
#   token=$(uuidgen)
#   stop_commands "$token"
#   echo "::warning:: This will NOT be rendered as a warning"
#   resume_commands "$token"
#   echo "::warning:: This WILL be rendered as a warning again"
stop_commands() {
  local token="$1"
  if $IS_GITHUB_ACTIONS; then
    echo "::stop-commands::${token}"
  fi
}

# Resume processing workflow commands after a previous stop_commands call.
# The token must match the one passed to stop_commands.
# Syntax: ::{endtoken}::
#
# Example: see stop_commands above
resume_commands() {
  local token="$1"
  if $IS_GITHUB_ACTIONS; then
    echo "::${token}::"
  fi
}

# Enable or disable echoing of workflow commands. When enabled (on) the command
# itself is printed to the log in addition to being executed, which is useful
# for debugging. Pass "on" or "off".
# Syntax: ::echo::on | ::echo::off
set_command_echo() {
  local setting="$1"
  if $IS_GITHUB_ACTIONS; then
    echo "::echo::${setting}"
  fi
}

# Set an environment variable that is available to all subsequent steps in the
# current job. The step that sets the variable does NOT see the new value — only
# later steps do. Writes to the $GITHUB_ENV file.
#
# Example:
#   set_env "MY_VAR" "some_value"
#   # In a subsequent step: echo "$MY_VAR" → some_value
set_env() {
  local name="$1"
  local value="$2"
  if $IS_GITHUB_ACTIONS; then
    echo "${name}=${value}" >> "$GITHUB_ENV"
  else
    export "${name}=${value}"
  fi
}

# Set a step output parameter that can be referenced by later steps via
# ${{ steps.<step_id>.outputs.<name> }}. The step must have an `id` defined in
# the workflow YAML. Writes to the $GITHUB_OUTPUT file.
#
# Example:
#   set_output "artifact_path" "build/output.zip"
#   # In a later step: ${{ steps.<id>.outputs.artifact_path }}
set_output() {
  local name="$1"
  local value="$2"
  if $IS_GITHUB_ACTIONS; then
    echo "${name}=${value}" >> "$GITHUB_OUTPUT"
  fi
}

# Append Markdown content to the job summary shown on the workflow run page.
# Each call appends; a newline is added automatically. Content supports GitHub
# Flavored Markdown. Writes to the $GITHUB_STEP_SUMMARY file. Each step is
# limited to 1 MiB of summary content.
#
# Example:
#   append_summary "### Build completed :white_check_mark:"
#   append_summary "| Target | Duration |"
#   append_summary "|--------|----------|"
#   append_summary "| iOS    | 3m 42s   |"
append_summary() {
  local content="$1"
  if $IS_GITHUB_ACTIONS; then
    echo "${content}" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "[summary] ${content}"
  fi
}
