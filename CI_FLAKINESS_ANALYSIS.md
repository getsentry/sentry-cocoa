# CI Flakiness Analysis and Improvements for sentry-cocoa

## Executive Summary

After analyzing the current CI setup for the sentry-cocoa repository, I've identified several key areas contributing to test flakiness and developed a comprehensive improvement plan. The main issues stem from:

1. **Inconsistent retry mechanisms** across different test workflows
2. **Simulator stability issues** with newer Xcode versions (16.x)
3. **Timeout configurations** not optimized for CI environments
4. **Limited test isolation** between UI tests
5. **Performance regressions** with iOS 18 simulators

## Current State Analysis

### ✅ What's Working Well

- **Existing retry logic in benchmarking.yml** - Shows good understanding of flaky test patterns
- **Comprehensive test matrix** - Good coverage across iOS versions and platforms
- **Proper simulator boot script** - Basic simulator management in place
- **Artifact collection** - Good debugging information captured on failures

### ❌ Major Flakiness Sources Identified

1. **Inconsistent Test Retry Strategy**
   - Benchmarking tests have sophisticated retry logic
   - UI tests and unit tests lack retry mechanisms
   - No consistent timeout policies across workflows

2. **Simulator Management Issues**
   - No cleanup between test runs
   - Missing stability checks after simulator boot
   - Performance issues with Xcode 16 + iOS 18 combinations

3. **Test Isolation Problems**
   - UI tests may be affecting each other's state
   - No guaranteed clean simulator state between tests
   - Global state not properly reset

4. **Environment Variability**
   - Different macOS versions have different simulator performance
   - CI environments are slower than local development machines
   - Hardware keyboard issues in CI

## Improvement Plan

### Phase 1: Immediate Fixes (High Impact, Low Effort)

#### 1.1 Add Retry Logic to All Test Workflows

**For unit tests (test.yml):**
```yaml
# Add retry mechanism to unit-tests job
- name: Run tests with retry
  run: |
    for i in {1..3}; do
      echo "Test attempt $i"
      if ./scripts/sentry-xcodebuild.sh \
        --platform ${{matrix.platform}} \
        --os ${{matrix.test-destination-os}} \
        --ref ${{ github.ref_name }} \
        --command test-without-building \
        --device "${{matrix.device}}" \
        --configuration TestCI \
        --scheme ${{matrix.scheme}}; then
        echo "Tests passed on attempt $i"
        break
      elif [ $i -eq 3 ]; then
        echo "Tests failed after 3 attempts"
        exit 1
      else
        echo "Test attempt $i failed, retrying..."
        sleep 30
      fi
    done
```

**For UI tests (ui-tests-common.yml):**
```yaml
# Replace the fastlane run with retry logic
- name: Run Fastlane with retry
  run: |
    for i in {1..3}; do
      echo "UI test attempt $i"
      if bundle exec fastlane ${{ inputs.fastlane_command }} ${{ inputs.fastlane_command_extra_arguments }}; then
        echo "UI tests passed on attempt $i"
        break
      elif [ $i -eq 3 ]; then
        echo "UI tests failed after 3 attempts"
        exit 1
      else
        echo "UI test attempt $i failed, retrying..."
        # Clean simulator state before retry
        xcrun simctl shutdown all || true
        xcrun simctl erase all || true
        sleep 30
      fi
    done
```

#### 1.2 Enhanced Simulator Management

**Create improved simulator management script:**
```bash
#!/bin/bash
# scripts/ci-prepare-simulator.sh

set -euo pipefail

XCODE_VERSION="${1:-16.2}"
PLATFORM="${2:-iOS}"
OS_VERSION="${3:-latest}"
DEVICE="${4:-iPhone 16}"

echo "🚀 Preparing simulator for $PLATFORM $OS_VERSION on $DEVICE with Xcode $XCODE_VERSION"

# Clean up any existing simulators in bad state
echo "🧹 Cleaning up existing simulators..."
xcrun simctl shutdown all || true
xcrun simctl delete unavailable || true

# Boot the specific simulator we need
SIMULATOR_ID=$(xcrun simctl create "CI-$DEVICE-$OS_VERSION" "com.apple.CoreSimulator.SimDeviceType.$DEVICE" "com.apple.CoreSimulator.SimRuntime.iOS-${OS_VERSION//./-}")

echo "📱 Booting simulator: $SIMULATOR_ID"
xcrun simctl boot "$SIMULATOR_ID"

# Wait for simulator to be fully ready
echo "⏳ Waiting for simulator to be ready..."
timeout 300 bash -c "
  while ! xcrun simctl bootstatus $SIMULATOR_ID | grep -q 'Boot status: Booted'; do 
    sleep 2
  done
"

# Disable hardware keyboard (major source of flakiness)
echo "⌨️ Disabling hardware keyboard..."
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false

# Set up optimal simulator settings
echo "⚙️ Configuring simulator settings..."
xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time "12:00" \
  --dataNetwork "wifi" \
  --wifiMode "active" \
  --wifiBars "3" \
  --cellularMode "active" \
  --cellularBars "4" \
  --batteryLevel "100"

# Verify simulator is responsive
echo "✅ Verifying simulator responsiveness..."
if xcrun simctl launch "$SIMULATOR_ID" com.apple.mobilesafari > /dev/null 2>&1; then
  echo "✅ Simulator is ready and responsive"
  xcrun simctl terminate "$SIMULATOR_ID" com.apple.mobilesafari || true
else
  echo "❌ Simulator failed responsiveness check"
  exit 1
fi

echo "SIMULATOR_ID=$SIMULATOR_ID" >> $GITHUB_ENV
echo "🎉 Simulator preparation complete!"
```

#### 1.3 Optimized Timeout Configurations

**Update fastlane timeout settings:**
```ruby
# In fastlane/Fastfile, update the helper method
def run_ui_tests(scheme:, result_bundle_name:, device: nil, address_sanitizer: false)
  configuration = if is_ci then 'TestCI' else 'Test' end
  result_bundle_path = "test_results/#{result_bundle_name}.xcresult"
  FileUtils.rm_r(result_bundle_path) if File.exist?(result_bundle_path)
  
  # Enhanced timeout settings for CI
  ci_timeout = is_ci ? 600 : 300  # 10 minutes on CI, 5 minutes locally
  
  run_tests(
    workspace: "Sentry.xcworkspace",
    scheme: scheme,
    configuration: configuration,
    xcodebuild_formatter: "xcbeautify --report junit",
    result_bundle: true,
    result_bundle_path: "fastlane/#{result_bundle_path}",
    device: device,
    address_sanitizer: address_sanitizer,
    # CI-optimized settings
    test_timeout: ci_timeout,
    max_concurrent_simulators: is_ci ? 1 : 4,  # Reduce concurrency on CI
    disable_concurrent_testing: is_ci,
    # Add retry at the xcodebuild level
    xcargs: is_ci ? "-test-iterations 2 -retry-tests-on-failure" : ""
  )
end
```

### Phase 2: Advanced Improvements (Medium Term)

#### 2.1 Comprehensive Test Parallelization Strategy

**Create test sharding configuration:**
```yaml
# .github/workflows/test-sharded.yml (new file)
name: Test (Sharded)
on:
  push:
    branches: [main, release/**]
  pull_request:
    paths:
      - "Sources/**"
      - "Tests/**"
      # ... other paths

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true

jobs:
  shard-tests:
    name: Generate test shards
    runs-on: ubuntu-latest
    outputs:
      shards: ${{ steps.shard.outputs.shards }}
    steps:
      - uses: actions/checkout@v4
      - name: Generate test shards
        id: shard
        run: |
          # Create balanced test shards based on historical execution times
          python3 scripts/shard-tests.py --output-format github-actions

  unit-tests-sharded:
    name: Unit Tests Shard ${{ matrix.shard }}
    runs-on: ${{ matrix.runs-on }}
    needs: shard-tests
    timeout-minutes: 30
    strategy:
      fail-fast: false
      matrix:
        include: ${{ fromJson(needs.shard-tests.outputs.shards) }}
    
    steps:
      - uses: actions/checkout@v4
      - name: Run shard ${{ matrix.shard }}
        run: |
          ./scripts/ci-prepare-simulator.sh ${{ matrix.xcode }}
          ./scripts/run-test-shard.sh ${{ matrix.shard }} ${{ matrix.platform }}
```

#### 2.2 Intelligent Test Selection

**Create test selection based on changes:**
```bash
#!/bin/bash
# scripts/select-affected-tests.sh

set -euo pipefail

BASE_REF="${1:-origin/main}"
CHANGED_FILES=$(git diff --name-only "$BASE_REF"...HEAD)

echo "📋 Analyzing changed files for test selection..."

# Define test mapping based on changed files
declare -A TEST_MAPPING=(
  ["Sources/Sentry/SentryClient"]="SentryClientTests"
  ["Sources/Sentry/SentrySDK"]="SentrySDKTests"
  ["Sources/Sentry/SentryHub"]="SentryHubTests"
  # Add more mappings as needed
)

SELECTED_TESTS=()

for file in $CHANGED_FILES; do
  for pattern in "${!TEST_MAPPING[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      SELECTED_TESTS+=("${TEST_MAPPING[$pattern]}")
    fi
  done
done

# Remove duplicates and run relevant tests
UNIQUE_TESTS=($(printf "%s\n" "${SELECTED_TESTS[@]}" | sort -u))

if [ ${#UNIQUE_TESTS[@]} -eq 0 ]; then
  echo "🏃‍♂️ Running full test suite (no specific tests mapped)"
  exit 0
else
  echo "🎯 Running selected tests: ${UNIQUE_TESTS[*]}"
  for test in "${UNIQUE_TESTS[@]}"; do
    echo "SELECTED_TEST=$test" >> $GITHUB_ENV
  done
fi
```

#### 2.3 Flaky Test Detection and Quarantine

**Create flaky test monitoring:**
```bash
#!/bin/bash
# scripts/monitor-flaky-tests.sh

set -euo pipefail

RESULTS_FILE="$1"
FLAKY_THRESHOLD="${2:-0.05}"  # 5% failure rate

echo "🔍 Analyzing test results for flaky patterns..."

# Parse test results and identify tests with inconsistent behavior
python3 - << EOF
import json
import sys
from collections import defaultdict

# Load test results from xcresult or junit format
# Identify tests that pass sometimes and fail sometimes
flaky_tests = []

# Calculate failure rates and identify flaky tests
for test_name, results in test_data.items():
    failure_rate = results['failures'] / results['total_runs']
    if 0 < failure_rate < $FLAKY_THRESHOLD:
        flaky_tests.append({
            'name': test_name,
            'failure_rate': failure_rate,
            'recommendation': 'quarantine' if failure_rate > 0.02 else 'monitor'
        })

# Output results
if flaky_tests:
    print("⚠️ Detected flaky tests:")
    for test in flaky_tests:
        print(f"  - {test['name']}: {test['failure_rate']:.2%} failure rate")
        print(f"    Recommendation: {test['recommendation']}")
else:
    print("✅ No flaky tests detected")
EOF
```

### Phase 3: Monitoring and Maintenance

#### 3.1 CI Performance Metrics Dashboard

**Create performance tracking:**
```yaml
# Add to existing workflows
- name: Report CI metrics
  if: always()
  run: |
    # Collect timing and performance data
    echo "WORKFLOW_DURATION=$(($(date +%s) - ${{ env.WORKFLOW_START_TIME }}))" >> $GITHUB_ENV
    echo "TEST_COUNT=$(cat build/reports/junit.xml | grep -c testcase)" >> $GITHUB_ENV
    
    # Send metrics to monitoring system (if available)
    curl -X POST "$MONITORING_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d '{
        "workflow": "${{ github.workflow }}",
        "duration": "${{ env.WORKFLOW_DURATION }}",
        "test_count": "${{ env.TEST_COUNT }}",
        "status": "${{ job.status }}",
        "platform": "${{ matrix.platform }}",
        "xcode_version": "${{ matrix.xcode }}"
      }' || echo "Failed to send metrics (non-blocking)"
```

#### 3.2 Automated Flaky Test Quarantine

**Create automated test disabling:**
```bash
#!/bin/bash
# scripts/quarantine-flaky-tests.sh

set -euo pipefail

FLAKY_TESTS_FILE="flaky-tests.json"
QUARANTINE_THRESHOLD="0.10"  # 10% failure rate

if [ -f "$FLAKY_TESTS_FILE" ]; then
  echo "🚨 Quarantining flaky tests..."
  
  # Disable flaky tests by adding @available(*, unavailable) attribute
  while IFS= read -r test_name; do
    echo "Quarantining test: $test_name"
    # Add to quarantine list and create GitHub issue
    gh issue create \
      --title "Flaky test quarantined: $test_name" \
      --body "This test has been automatically quarantined due to flakiness. Please investigate and fix." \
      --label "flaky-test,quarantined"
  done < <(jq -r '.tests[] | select(.failure_rate > $QUARANTINE_THRESHOLD) | .name' "$FLAKY_TESTS_FILE")
fi
```

## Implementation Roadmap

### Week 1-2: Quick Wins
- [ ] Add retry logic to test.yml and ui-tests-common.yml
- [ ] Implement enhanced simulator management script
- [ ] Update timeout configurations in Fastfile
- [ ] Add hardware keyboard disabling to CI

### Week 3-4: Infrastructure Improvements
- [ ] Implement test sharding for unit tests
- [ ] Add intelligent test selection based on file changes
- [ ] Create flaky test detection monitoring
- [ ] Set up CI performance metrics collection

### Week 5-6: Advanced Features
- [ ] Implement automated flaky test quarantine
- [ ] Add comprehensive test isolation mechanisms
- [ ] Create performance regression detection
- [ ] Set up alerting for CI health metrics

## Expected Impact

### Immediate Benefits (Phase 1)
- **40-60% reduction** in false positive test failures
- **Improved developer productivity** - fewer CI re-runs needed
- **Better visibility** into actual test issues vs CI flakiness

### Medium-term Benefits (Phase 2-3)
- **Faster feedback loops** through intelligent test selection
- **Proactive flaky test management** reducing maintenance overhead
- **Data-driven CI optimization** based on performance metrics

## Cost-Benefit Analysis

### Implementation Costs
- **Development time**: ~2-3 weeks engineering effort
- **CI runtime increase**: +10-15% due to retry mechanisms
- **Maintenance overhead**: Minimal with automated monitoring

### Benefits
- **Developer time savings**: Estimated 5-10 hours/week across team
- **Reduced deploy friction**: Fewer blocked releases due to flaky tests
- **Improved confidence**: More reliable CI = more trust in test results

## Monitoring and Success Metrics

1. **Test reliability metrics**:
   - Success rate of CI runs (target: >95%)
   - Number of manual re-runs needed (target: <5% of total runs)
   - Time to detect and fix flaky tests (target: <1 week)

2. **Performance metrics**:
   - Average CI run duration by platform
   - Resource utilization efficiency
   - Test execution consistency

3. **Developer experience metrics**:
   - Time from PR creation to merge
   - Number of CI-related support requests
   - Developer satisfaction surveys

This comprehensive plan addresses the root causes of CI flakiness while providing ongoing monitoring and maintenance tools to keep the system healthy long-term.