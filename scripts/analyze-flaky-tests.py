#!/usr/bin/env python3
"""
Flaky Test Analyzer

This script analyzes JUnit XML test results from multiple test runs to identify
flaky tests. A test is considered flaky if it both passes and fails across
different runs.

Usage:
    python3 analyze-flaky-tests.py [--runs N] [--output-file path]
"""

import sys
import xml.etree.ElementTree as ET
import glob
import json
import argparse
from collections import defaultdict
from typing import Dict, List, Tuple, Any


def parse_junit_xml(xml_file: str) -> Dict[str, str]:
    """Parse JUnit XML and return test results."""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        # Handle both JUnit 4 and JUnit 5 formats
        testsuites = root.findall('.//testsuite') or [root]
        
        results = {}
        for testsuite in testsuites:
            for testcase in testsuite.findall('.//testcase'):
                class_name = testcase.get('classname', 'Unknown')
                test_name = testcase.get('name', 'Unknown')
                full_test_name = f"{class_name}.{test_name}"
                
                # Check if test failed
                failure = testcase.find('.//failure')
                error = testcase.find('.//error')
                skipped = testcase.find('.//skipped')
                
                if skipped is not None:
                    status = 'skipped'
                elif failure is not None or error is not None:
                    status = 'failed'
                else:
                    status = 'passed'
                
                results[full_test_name] = status
        
        return results
    except Exception as e:
        print(f"Error parsing {xml_file}: {e}", file=sys.stderr)
        return {}


def analyze_flaky_tests(
    result_pattern: str = 'test-results-run-*/junit.xml'
) -> Tuple[List[Dict[str, Any]], int]:
    """Analyze test results to find flaky tests."""
    test_results = defaultdict(list)
    
    # Find all test result files
    result_files = glob.glob(result_pattern)
    result_files.sort()
    
    if not result_files:
        print(f"No test result files found matching pattern: {result_pattern}",
              file=sys.stderr)
        return [], 0
    
    print(f"Found {len(result_files)} test result files")
    
    for i, xml_file in enumerate(result_files, 1):
        print(f"Processing run {i}: {xml_file}")
        
        results = parse_junit_xml(xml_file)
        for test_name, status in results.items():
            test_results[test_name].append(status)
    
    # Analyze flaky tests
    flaky_tests = []
    total_runs = len(result_files)
    
    for test_name, statuses in test_results.items():
        if len(statuses) != total_runs:
            print(f"Warning: Test {test_name} has {len(statuses)} results "
                  f"for {total_runs} runs", file=sys.stderr)
            continue
        
        passed_count = statuses.count('passed')
        failed_count = statuses.count('failed')
        skipped_count = statuses.count('skipped')
        
        # A test is flaky if it both passed and failed (not just skipped)
        if passed_count > 0 and failed_count > 0:
            flakiness_rate = failed_count / total_runs
            flaky_tests.append({
                'test_name': test_name,
                'passed': passed_count,
                'failed': failed_count,
                'skipped': skipped_count,
                'total_runs': total_runs,
                'flakiness_rate': flakiness_rate,
                'statuses': statuses
            })
    
    # Sort by flakiness rate (highest first)
    flaky_tests.sort(key=lambda x: x['flakiness_rate'], reverse=True)
    
    return flaky_tests, total_runs


def generate_summary(flaky_tests: List[Dict[str, Any]]) -> Dict[str, int]:
    """Generate summary statistics for flaky tests."""
    if not flaky_tests:
        return {
            'total_flaky_tests': 0,
            'highly_flaky_tests': 0,
            'moderately_flaky_tests': 0,
            'slightly_flaky_tests': 0
        }
    
    highly_flaky = len([t for t in flaky_tests if t['flakiness_rate'] >= 0.5])
    moderately_flaky = len([t for t in flaky_tests 
                           if 0.2 <= t['flakiness_rate'] < 0.5])
    slightly_flaky = len([t for t in flaky_tests if t['flakiness_rate'] < 0.2])
    
    return {
        'total_flaky_tests': len(flaky_tests),
        'highly_flaky_tests': highly_flaky,
        'moderately_flaky_tests': moderately_flaky,
        'slightly_flaky_tests': slightly_flaky
    }


def main():
    parser = argparse.ArgumentParser(
        description='Analyze flaky tests from JUnit XML results'
    )
    parser.add_argument(
        '--pattern', 
        default='test-results-run-*/junit.xml',
        help='Glob pattern for test result files '
             '(default: test-results-run-*/junit.xml)'
    )
    parser.add_argument(
        '--output-file', 
        default='flaky_tests_report.json',
        help='Output file for detailed report '
             '(default: flaky_tests_report.json)'
    )
    parser.add_argument(
        '--verbose', '-v', 
        action='store_true',
        help='Verbose output'
    )
    
    args = parser.parse_args()
    
    flaky_tests, total_runs = analyze_flaky_tests(args.pattern)
    summary = generate_summary(flaky_tests)
    
    print("\n=== Flaky Test Analysis ===")
    print(f"Total test runs: {total_runs}")
    print(f"Flaky tests found: {len(flaky_tests)}")
    print()
    
    if flaky_tests:
        print("Flaky Tests (sorted by flakiness rate):")
        print("-" * 80)
        for test in flaky_tests:
            print(f"Test: {test['test_name']}")
            print(f"  Flakiness Rate: {test['flakiness_rate']:.1%} "
                  f"({test['failed']}/{test['total_runs']} failed)")
            if args.verbose:
                print(f"  Results: {' '.join(test['statuses'])}")
            print()
        
        print("Summary:")
        print(f"  Highly flaky (≥50% failure rate): {summary['highly_flaky_tests']}")
        print(f"  Moderately flaky (20-49% failure rate): "
              f"{summary['moderately_flaky_tests']}")
        print(f"  Slightly flaky (<20% failure rate): "
              f"{summary['slightly_flaky_tests']}")
    else:
        print("No flaky tests found! 🎉")
    
    # Save detailed results to file
    report = {
        'total_runs': total_runs,
        'flaky_tests': flaky_tests,
        'summary': summary
    }
    
    with open(args.output_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\nDetailed report saved to {args.output_file}")
    
    # Exit with error code if flaky tests found
    if flaky_tests:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main() 
