#!/bin/bash
# Xcode's $(inherited) is a literal in the assertions, not shell interpolation.
# shellcheck disable=SC2016
set -euo pipefail

# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/ci-utils.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir)"
WORK_DIR=""

usage() {
    log_info "Usage: $(basename "$0") [--work-dir|-w PATH]"
    log_info "  -w, --work-dir PATH  New directory for fixtures and logs (default: temporary directory)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--work-dir) [[ $# -ge 2 ]] || usage; WORK_DIR="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ -n "$WORK_DIR" ]]; then
    [[ ! -e "$WORK_DIR" ]] || { log_error "Work directory already exists: $WORK_DIR"; exit 1; }
    mkdir -p "$WORK_DIR"
else
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sentry-v10-selection.XXXXXX")"
fi
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
log_info "Evidence: $WORK_DIR"

fixture="$WORK_DIR/repo"
tools="$WORK_DIR/tools"
mkdir -p "$fixture/TestApps" "$tools"
ln -s "$REPO_ROOT/scripts" "$fixture/scripts"

# Exercise the real Make recipes and YAML patchers without launching Xcode, building
# an app, or closing the user's IDE. Each external command records its environment.
cat > "$tools/xcodegen" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "${SDK_V10-unset}" > "$RECORD/generator-env"
cp "$2" "$RECORD/generated.yml"
SH
cat > "$tools/xcodebuild" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "${SDK_V10-unset}" > "$RECORD/build-env"
printf '%s\n' "$@" > "$RECORD/build-args"
printf '** BUILD SUCCEEDED **\n'
SH
cat > "$tools/xcbeautify" <<'SH'
#!/bin/bash
while IFS= read -r line; do printf '%s\n' "$line"; done
SH
cat > "$tools/killall" <<'SH'
#!/bin/bash
exit 0
SH
cat > "$tools/xed" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "${SDK_V10-unset}" > "$RECORD/build-env"
SH
chmod +x "$tools/"*

apps=(DistributionSample iOS-ObjectiveC iOS-ObjectiveCpp-NoModules iOS-Swift iOS-SwiftUI SPM macOS-CLI-Xcode macOS-Swift macOS-SwiftUI tvOS-Swift visionOS-Swift watchOS-Swift)
for app in "${apps[@]}"; do
    mkdir -p "$fixture/TestApps/$app"
    printf '%s\n' 'name: Probe' 'packages:' '  Sentry:' '    path: ../..' 'targets:' '  Probe:' '    dependencies:' '      - package: Sentry' '        products: [SentrySPM]' > "$fixture/TestApps/$app/$app.yml"
done

targets=()
for app in "${apps[@]}"; do targets+=("build-testapp-v10-$app"); done
targets+=(test-testapp-v10-macOS-CLI-Xcode switch-v10)
for target in "${targets[@]}"; do
    record="$WORK_DIR/$target"
    mkdir -p "$record"
    env -u SDK_V10 PATH="$tools:$PATH" RECORD="$record" GIT_DIR="$REPO_GIT_DIR" GIT_WORK_TREE="$REPO_ROOT" make --no-print-directory \
        -C "$fixture" -f "$REPO_ROOT/Makefile" "$target" GIT-REF=selection-test FOR_AGENTS=true \
        > "$record/make.log" 2>&1
    for stage in generator build; do
        [[ "$(< "$record/$stage-env")" == 1 ]] || {
            log_error "$target: $stage must receive SDK_V10=1; see $record/make.log"
            exit 1
        }
    done
    yq -e '.packages.Sentry.traits // [] | contains(["V10"]) | not' "$record/generated.yml" >/dev/null
    yq -e '.targets.Probe.dependencies[0].products | join(",") == "Sentry"' "$record/generated.yml" >/dev/null
    yq -e '.targets.Probe.settings.base.SWIFT_ACTIVE_COMPILATION_CONDITIONS == "$(inherited) SDK_V10"' "$record/generated.yml" >/dev/null
    yq -e '.targets.Probe.settings.base.GCC_PREPROCESSOR_DEFINITIONS == "$(inherited) SDK_V10=1"' "$record/generated.yml" >/dev/null
    log_info "PASS $target environment, source product and compiler settings"
done

# Calling the generator directly must not silently create a V9 package graph.
if env -u SDK_V10 PATH="$tools:$PATH" "$REPO_ROOT/scripts/generate-testapp-v10.sh" \
    --spec "$fixture/TestApps/SPM/SPM.yml" > "$WORK_DIR/missing-env.log" 2>&1; then
    log_error "Project generation without SDK_V10=1 must fail"
    exit 1
fi
grep -q 'SDK_V10=1' "$WORK_DIR/missing-env.log"
log_info "PASS project generation rejects missing SDK_V10=1"
log_info "All V10 development selection checks passed"
