# UI Tests Debug Logging - Complete Configuration

This document summarizes all the debug logging enhancements added to the GitHub Actions UI test workflows.

## Overview

Maximum debug logging has been enabled across all UI test workflows to help diagnose and debug test failures, build issues, and flaky tests. This includes:

1. **XCBuild Debug Logging** - Generates detailed `build.trace` files
2. **Verbose Xcodebuild Output** - Shows all build commands and settings
3. **Fastlane Verbose Mode** - Detailed test execution logs
4. **Comprehensive Log Collection** - Automatic artifact uploads for all debug data

## Changes Made

### 1. Environment Variables (All UI Test Workflows)

Added to:

- `.github/workflows/ui-tests.yml`
- `.github/workflows/ui-tests-critical.yml`

```yaml
env:
  FASTLANE_XCODEBUILD_SETTINGS_RETRIES: 5
  FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 60
  FASTLANE_XCODEBUILD_LOG_LEVEL: "verbose"

  # Enable maximum xcodebuild logging
  XCBuildLogLevel: "Verbose"

  # Enable xcbuild debug logging - generates build.trace files
  EnableBuildDebugging: "YES"
  EnableDebugActivityLogs: "YES"

  # Show all build settings
  VERBOSE_SCRIPT_LOGGING: "YES"

  # Fastlane verbose output
  FASTLANE_VERBOSE: "true"

  # Disable xcpretty to get raw xcodebuild output
  FASTLANE_DISABLE_XCPRETTY: "true"
```

### 2. XCBuild Debug Flags Setup

Added to: `.github/workflows/ui-tests-common.yml`

A new step "Enable XCBuild Debug Logging" that:

- Runs `defaults write com.apple.dt.XCBuild EnableDebugActivityLogs -bool YES`
- Runs `defaults write com.apple.dt.XCBuild EnableBuildDebugging -bool YES`
- Shows current XCBuild settings
- Displays all debugging-related environment variables

**What it does:**

- Enables generation of `build.trace` files in DerivedData
- These files contain detailed information about what triggered each build rule
- Useful for debugging incremental build issues

### 3. System Information Display

Added to: `.github/workflows/ui-tests-common.yml`

A new step "Show Simulator and Xcode Information" that displays:

- All available simulators
- Currently booted simulators
- Xcode version information
- Available SDK versions
- Xcode installation path

### 4. Build Artifacts Listing

Added to: `.github/workflows/ui-tests-common.yml`

A new step "List DerivedData and Build Artifacts" that shows:

- DerivedData directory structure
- XCBuildData directory locations
- All `build.trace` file locations
- Fastlane test_output directory contents

### 5. Enhanced Fastlane Configuration

Modified: `fastlane/Fastfile`

Updated the `run_ui_tests` helper method to:

- Add `-verbose` flag when `FASTLANE_VERBOSE=true`
- Add `-showBuildSettings` flag when `VERBOSE_SCRIPT_LOGGING=YES`
- Enable raw output style when `FASTLANE_DISABLE_XCPRETTY=true`
- Set `buildlog_path` to capture all build logs

### 6. Comprehensive Artifact Collection

Added multiple artifact upload steps to: `.github/workflows/ui-tests-common.yml`

#### 6a. XCBuild Debug Traces

- Collects all `build.trace` files from DerivedData
- Renames them with timestamps to avoid conflicts
- Uploads as: `{fastlane_command}{files_suffix}_xcbuild_traces`

#### 6b. Xcode Activity Logs

- Collects all `*.xcactivitylog` files
- These contain detailed build activity information
- Uploads as: `{fastlane_command}{files_suffix}_xcode_activity_logs`

#### 6c. Comprehensive Build Logs

- Copies entire `Logs` directory from DerivedData
- Includes build settings and intermediates
- Generates DerivedData directory structure
- Uploads as: `{fastlane_command}{files_suffix}_comprehensive_build_logs`

#### 6d. Existing Artifacts (Already Present)

- Result bundles (`.xcresult`)
- iOS Simulator crash logs
- Raw test logs from fastlane
- Screenshots on failure

## How to Use This Information

### 1. When a Test Fails

After a test failure, check the following artifacts (in order):

1. **Result Bundle** - View test results and screenshots
   - Download `{fastlane_command}{files_suffix}.xcresult`
   - Open in Xcode to see test failures

2. **Raw Test Logs** - Check for detailed test execution
   - Download `{fastlane_command}{files_suffix}_raw_output`
   - Look for assertion failures, timeouts, or crashes

3. **Crash Logs** - Check for app crashes
   - Download `{fastlane_command}{files_suffix}_crash_logs`
   - Analyze crash reports

### 2. When Investigating Build Issues

1. **XCBuild Debug Traces** - Understand why builds are triggered
   - Download `{fastlane_command}{files_suffix}_xcbuild_traces`
   - Open `build_trace_*.txt` files
   - Search for `rule-needs-to-run` to find why builds were triggered
   - Look for `signature-changed` or `input-rebuilt` reasons

2. **Comprehensive Build Logs** - See full build output
   - Download `{fastlane_command}{files_suffix}_comprehensive_build_logs`
   - Check `derived-data-structure.txt` for directory layout
   - Review logs in the `Logs/` subdirectory

3. **Xcode Activity Logs** - Detailed Xcode operations
   - Download `{fastlane_command}{files_suffix}_xcode_activity_logs`
   - These are binary files, use `xclogparser` to parse them

### 3. Analyzing build.trace Files

Reference: https://asifmohd.github.io/ios/2021/03/11/xcbuild-debug-info.html

The `build.trace` files contain rules and tasks:

- Each rule can trigger a task
- Look for `rule-needs-to-run` entries
- Find the reason (signature-changed, input-rebuilt, etc.)
- Trace back to parent rules to find root cause

Example workflow:

1. Find a module that's rebuilding unexpectedly
2. Search for `CompileSwiftSources` for that module
3. Find the associated rule ID
4. Search for that rule ID throughout the file
5. Find parent rules and reasons for rebuild
6. Identify misconfigured build settings or dependencies

### 4. Performance Impact

⚠️ **Important Notes:**

1. **Slower Builds**: Debug logging adds overhead to builds
   - `EnableBuildDebugging` slows down the build system
   - Verbose output increases log processing time

2. **Larger Artifacts**: More logs = more storage used
   - build.trace files can be several MB each
   - DerivedData logs can be 100+ MB
   - Monitor GitHub Actions storage usage

3. **Longer CI Times**: Collecting and uploading artifacts takes time
   - Each artifact upload adds 10-30 seconds
   - Only runs on failure/cancellation to minimize impact

## Disabling Debug Logging

To temporarily disable debug logging for specific workflows:

1. Comment out the environment variables in the workflow file
2. Comment out the "Enable XCBuild Debug Logging" step
3. Comment out the artifact collection steps

Or, to disable just the most expensive options:

```yaml
env:
  # Keep verbose output
  FASTLANE_VERBOSE: "true"
  XCBuildLogLevel: "Verbose"

  # Disable expensive debug flags
  # EnableBuildDebugging: "YES"
  # EnableDebugActivityLogs: "YES"
```

## Tools for Analysis

### xclogparser

- Install: `brew install xclogparser`
- Parse activity logs: `xclogparser parse --file activity.xcactivitylog`
- Export HTML report: `xclogparser parse --reporter html`
- Export JSON: `xclogparser parse --reporter json`

### xcbeautify

- Already used in the workflows
- Formats xcodebuild output for readability
- Can be disabled with `FASTLANE_DISABLE_XCPRETTY=true`

## Workflow Triggers

Both UI test workflows have been configured to trigger on push to:

- `main` branch (production)
- `philprime/debug-flaky-ui-tests` branch (debugging branch)

This allows testing the debug logging configuration without creating a PR.

## Files Modified

1. `.github/workflows/ui-tests.yml` - Added environment variables and debug branch trigger
2. `.github/workflows/ui-tests-common.yml` - Added debug steps and artifact collection
3. `.github/workflows/ui-tests-critical.yml` - Added environment variables and debug branch trigger
4. `fastlane/Fastfile` - Enhanced run_ui_tests helper with verbose flags

## Expected Artifacts on Test Failure

For each failing test run, you'll now get:

1. `{test_name}_raw_output` - Fastlane logs and scan output
2. `{test_name}_crash_logs` - iOS Simulator crash logs
3. `{test_name}_xcbuild_traces` - Build trace files (NEW)
4. `{test_name}_xcode_activity_logs` - Xcode activity logs (NEW)
5. `{test_name}_comprehensive_build_logs` - Full DerivedData logs (NEW)
6. `{test_name}` - Test result bundles (.xcresult)

Plus screenshots if the test fails.

## Using GitHub CLI to Access Logs

After pushing to the `philprime/debug-flaky-ui-tests` branch, you can use the GitHub CLI to access logs and artifacts:

### View Workflow Runs

```bash
# List recent workflow runs
gh run list --branch philprime/debug-flaky-ui-tests

# View specific workflow runs
gh run list --workflow "UI Tests" --branch philprime/debug-flaky-ui-tests

# Get detailed view of a specific run
gh run view <run-id>
```

### Download Artifacts

```bash
# List all artifacts for a run
gh run view <run-id> --log

# Download all artifacts from a run
gh run download <run-id>

# Download specific artifact
gh run download <run-id> -n ui_tests_ios_swift_xcode_16.4-iPhone_16_Pro_xcbuild_traces

# Download to specific directory
gh run download <run-id> -D ./debug-logs
```

### Watch Live Logs

```bash
# Watch logs in real-time
gh run watch <run-id>

# View logs for a specific job
gh run view <run-id> --log --job <job-id>
```

### Quick Download All Debug Artifacts

```bash
# Download all xcbuild traces, activity logs, and comprehensive logs
gh run download <run-id> --pattern "*_xcbuild_traces" --pattern "*_xcode_activity_logs" --pattern "*_comprehensive_build_logs" --pattern "*_simulator_logs"
```

### Example Workflow

```bash
# 1. Push to debug branch
git push origin philprime/debug-flaky-ui-tests

# 2. Wait for workflow to start and get run ID
gh run list --workflow "UI Tests" --branch philprime/debug-flaky-ui-tests --limit 1

# 3. Watch the run
gh run watch <run-id>

# 4. If it fails, download all debug artifacts
gh run download <run-id> -D ./debug-artifacts

# 5. Analyze the logs
cd debug-artifacts
ls -la
```

## Next Steps

1. **Push to debug branch** to trigger workflows with full debug logging
2. **Monitor first few CI runs** using GitHub CLI to ensure logs are generated correctly
3. **Check artifact sizes** to ensure they're not too large (watch GitHub Actions storage usage)
4. **Analyze build.trace files** if you see unexpected rebuilds
5. **Fine-tune settings** if certain logs aren't providing value
6. **Document findings** from analyzing the debug logs
7. **Remove debug branch trigger** from workflows once debugging is complete

## Questions?

For more information on xcbuild debugging:

- https://asifmohd.github.io/ios/2021/03/11/xcbuild-debug-info.html
- https://github.com/apple/swift-llbuild
- `man xcodebuild` for all available flags

For GitHub CLI:

- https://cli.github.com/manual/gh_run
- `gh run --help` for all available commands
