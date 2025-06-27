#!/bin/bash
# Flaky test monitoring and analysis script
# Analyzes test results to identify patterns of flakiness and suggest actions

set -euo pipefail

# Configuration
RESULTS_DIR="${1:-build/reports}"
FLAKY_THRESHOLD="${2:-0.05}"  # 5% failure rate threshold
QUARANTINE_THRESHOLD="${3:-0.10}"  # 10% failure rate for quarantine
HISTORY_DAYS="${4:-30}"  # Days of history to analyze

# Output files
FLAKY_TESTS_REPORT="flaky-tests-report.json"
QUARANTINE_LIST="quarantine-candidates.txt"

echo "🔍 Analyzing test results for flaky patterns..."
echo "   Results directory: $RESULTS_DIR"
echo "   Flaky threshold: ${FLAKY_THRESHOLD}%"
echo "   Quarantine threshold: ${QUARANTINE_THRESHOLD}%"
echo "   Analysis period: $HISTORY_DAYS days"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to analyze JUnit XML results
analyze_junit_results() {
    local results_file="$1"
    
    if [ ! -f "$results_file" ]; then
        log "⚠️ JUnit results file not found: $results_file"
        return 1
    fi
    
    log "📊 Analyzing JUnit results: $results_file"
    
    # Extract test results using Python for robust XML parsing
    python3 -c "
import xml.etree.ElementTree as ET
import json
import sys
from collections import defaultdict

try:
    tree = ET.parse('$results_file')
    root = tree.getroot()
    
    test_results = defaultdict(lambda: {'total': 0, 'failures': 0, 'errors': 0, 'skipped': 0})
    
    # Parse testcase elements
    for testcase in root.findall('.//testcase'):
        classname = testcase.get('classname', 'Unknown')
        name = testcase.get('name', 'Unknown')
        test_key = f'{classname}.{name}'
        
        test_results[test_key]['total'] += 1
        
        # Check for failures and errors
        if testcase.find('failure') is not None:
            test_results[test_key]['failures'] += 1
        elif testcase.find('error') is not None:
            test_results[test_key]['errors'] += 1
        elif testcase.find('skipped') is not None:
            test_results[test_key]['skipped'] += 1
    
    # Output results as JSON
    print(json.dumps(dict(test_results), indent=2))
    
except Exception as e:
    print(f'Error parsing XML: {e}', file=sys.stderr)
    sys.exit(1)
" > /tmp/test_results.json
}

# Function to analyze xcresult bundles
analyze_xcresult_bundles() {
    local results_dir="$1"
    
    log "🔍 Searching for xcresult bundles in: $results_dir"
    
    # Find all xcresult bundles
    find "$results_dir" -name "*.xcresult" -type d 2>/dev/null | while read -r xcresult_path; do
        log "📦 Analyzing xcresult bundle: $xcresult_path"
        
        # Extract test results using xcresulttool
        if command -v xcrun >/dev/null 2>&1; then
            xcrun xcresulttool get --format json test-results --path "$xcresult_path" 2>/dev/null | \
            python3 -c "
import json
import sys
from collections import defaultdict

try:
    data = json.load(sys.stdin)
    test_results = defaultdict(lambda: {'total': 0, 'failures': 0, 'errors': 0, 'skipped': 0})
    
    def process_test_summaries(summaries, prefix=''):
        for summary in summaries.get('summaries', []):
            if summary.get('_type', {}).get('_name') == 'ActionTestSummary':
                for test_summary in summary.get('tests', {}).get('summaries', []):
                    test_name = f\"{prefix}{test_summary.get('name', 'Unknown')}\"
                    
                    for subtest in test_summary.get('subtests', {}).get('summaries', []):
                        full_test_name = f\"{test_name}.{subtest.get('name', 'Unknown')}\"
                        test_results[full_test_name]['total'] += 1
                        
                        # Check test result
                        test_status = subtest.get('testStatus', 'Unknown')
                        if test_status == 'Failure':
                            test_results[full_test_name]['failures'] += 1
                        elif test_status == 'Error':
                            test_results[full_test_name]['errors'] += 1
                        elif test_status == 'Skipped':
                            test_results[full_test_name]['skipped'] += 1
    
    process_test_summaries(data.get('actions', {}))
    print(json.dumps(dict(test_results), indent=2))
    
except Exception as e:
    print(f'Error parsing xcresult: {e}', file=sys.stderr)
    sys.exit(1)
" >> /tmp/test_results.json
        fi
    done
}

# Function to calculate flakiness metrics
calculate_flakiness() {
    log "📈 Calculating flakiness metrics..."
    
    python3 -c "
import json
import sys
from datetime import datetime, timedelta

# Load test results
test_data = {}
try:
    with open('/tmp/test_results.json', 'r') as f:
        for line in f:
            if line.strip():
                data = json.loads(line)
                for test_name, results in data.items():
                    if test_name not in test_data:
                        test_data[test_name] = {'total': 0, 'failures': 0, 'errors': 0, 'skipped': 0}
                    
                    for key in ['total', 'failures', 'errors', 'skipped']:
                        test_data[test_name][key] += results.get(key, 0)
except FileNotFoundError:
    print('No test results found to analyze')
    sys.exit(0)

# Analyze flakiness
flaky_tests = []
quarantine_candidates = []

for test_name, results in test_data.items():
    if results['total'] == 0:
        continue
    
    failure_rate = (results['failures'] + results['errors']) / results['total']
    
    # Identify flaky tests (inconsistent failures)
    if 0 < failure_rate < $FLAKY_THRESHOLD:
        flaky_tests.append({
            'name': test_name,
            'total_runs': results['total'],
            'failures': results['failures'],
            'errors': results['errors'],
            'failure_rate': failure_rate,
            'recommendation': 'monitor' if failure_rate < 0.02 else 'investigate'
        })
    
    # Identify quarantine candidates (high failure rate)
    elif failure_rate >= $QUARANTINE_THRESHOLD:
        quarantine_candidates.append({
            'name': test_name,
            'total_runs': results['total'],
            'failures': results['failures'],
            'errors': results['errors'],
            'failure_rate': failure_rate,
            'recommendation': 'quarantine'
        })

# Generate reports
report = {
    'analysis_date': datetime.now().isoformat(),
    'total_tests_analyzed': len(test_data),
    'flaky_tests': flaky_tests,
    'quarantine_candidates': quarantine_candidates,
    'summary': {
        'flaky_test_count': len(flaky_tests),
        'quarantine_candidate_count': len(quarantine_candidates),
        'overall_health': 'good' if len(flaky_tests) < 5 and len(quarantine_candidates) == 0 else 'needs_attention'
    }
}

# Save detailed report
with open('$FLAKY_TESTS_REPORT', 'w') as f:
    json.dump(report, f, indent=2)

# Save quarantine list
with open('$QUARANTINE_LIST', 'w') as f:
    for candidate in quarantine_candidates:
        f.write(f\"{candidate['name']}\n\")

# Print summary
print(f\"📊 Flakiness Analysis Summary:\")
print(f\"   Total tests analyzed: {len(test_data)}\")
print(f\"   Flaky tests detected: {len(flaky_tests)}\")
print(f\"   Quarantine candidates: {len(quarantine_candidates)}\")

if flaky_tests:
    print(f\"\n⚠️ Flaky Tests Detected:\")
    for test in sorted(flaky_tests, key=lambda x: x['failure_rate'], reverse=True):
        print(f\"   - {test['name']}: {test['failure_rate']:.2%} failure rate ({test['failures']}/{test['total_runs']} runs)\")
        print(f\"     Recommendation: {test['recommendation']}\")

if quarantine_candidates:
    print(f\"\n🚨 Quarantine Candidates:\")
    for candidate in sorted(quarantine_candidates, key=lambda x: x['failure_rate'], reverse=True):
        print(f\"   - {candidate['name']}: {candidate['failure_rate']:.2%} failure rate ({candidate['failures']}/{candidate['total_runs']} runs)\")

if not flaky_tests and not quarantine_candidates:
    print(f\"\n✅ No flaky tests detected - CI health looks good!\")
else:
    print(f\"\n💡 Recommendations:\")
    if flaky_tests:
        print(f\"   - Investigate flaky tests to identify root causes\")
        print(f\"   - Consider adding retry logic or improving test isolation\")
    if quarantine_candidates:
        print(f\"   - Consider quarantining tests with >10% failure rate\")
        print(f\"   - Create GitHub issues to track fixes for quarantined tests\")
"
}

# Function to generate GitHub Actions outputs
generate_github_outputs() {
    if [ "${GITHUB_OUTPUT:-}" ]; then
        log "📤 Generating GitHub Actions outputs..."
        
        # Read the report
        if [ -f "$FLAKY_TESTS_REPORT" ]; then
            flaky_count=$(jq -r '.summary.flaky_test_count' "$FLAKY_TESTS_REPORT")
            quarantine_count=$(jq -r '.summary.quarantine_candidate_count' "$FLAKY_TESTS_REPORT")
            health_status=$(jq -r '.summary.overall_health' "$FLAKY_TESTS_REPORT")
            
            echo "flaky_test_count=$flaky_count" >> "$GITHUB_OUTPUT"
            echo "quarantine_candidate_count=$quarantine_count" >> "$GITHUB_OUTPUT"
            echo "ci_health_status=$health_status" >> "$GITHUB_OUTPUT"
            
            # Set step summary for GitHub Actions
            if [ "${GITHUB_STEP_SUMMARY:-}" ]; then
                echo "## 🔍 Flaky Test Analysis Results" >> "$GITHUB_STEP_SUMMARY"
                echo "- **Total tests analyzed:** $(jq -r '.total_tests_analyzed' "$FLAKY_TESTS_REPORT")" >> "$GITHUB_STEP_SUMMARY"
                echo "- **Flaky tests detected:** $flaky_count" >> "$GITHUB_STEP_SUMMARY"
                echo "- **Quarantine candidates:** $quarantine_count" >> "$GITHUB_STEP_SUMMARY"
                echo "- **CI health status:** $health_status" >> "$GITHUB_STEP_SUMMARY"
                
                if [ "$flaky_count" -gt 0 ] || [ "$quarantine_count" -gt 0 ]; then
                    echo "" >> "$GITHUB_STEP_SUMMARY"
                    echo "⚠️ **Action Required:** Review the flaky tests report and consider implementing fixes." >> "$GITHUB_STEP_SUMMARY"
                fi
            fi
        fi
    fi
}

# Main execution
main() {
    # Clean up temporary files
    rm -f /tmp/test_results.json

    # Find and analyze test results
    if [ -d "$RESULTS_DIR" ]; then
        # Look for JUnit XML files
        find "$RESULTS_DIR" -name "*.xml" -type f 2>/dev/null | while read -r xml_file; do
            if grep -q "testcase" "$xml_file" 2>/dev/null; then
                analyze_junit_results "$xml_file"
            fi
        done
        
        # Look for xcresult bundles
        analyze_xcresult_bundles "$RESULTS_DIR"
        
        # Calculate flakiness metrics
        calculate_flakiness
        
        # Generate GitHub Actions outputs
        generate_github_outputs
        
        log "✅ Analysis complete. Reports saved:"
        log "   - Detailed report: $FLAKY_TESTS_REPORT"
        log "   - Quarantine list: $QUARANTINE_LIST"
        
    else
        log "❌ Results directory not found: $RESULTS_DIR"
        exit 1
    fi
}

# Run the analysis
main "$@"