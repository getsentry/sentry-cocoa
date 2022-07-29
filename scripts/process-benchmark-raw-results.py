#!/usr/bin/env python3

import argparse
import functools
import math
import sys

"""A script to parse an XCUITest console log, extract raw benchmark values, and statistically analyze the SDK profiler's CPU overhead."""

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_file_path', help='Path to the log file to parse.')
    args = parser.parse_args()

    def extract_values(line):
        """Given a log line with benchmark values, return a list of integer results it contains."""
        return line.split('[Sentry Benchmark]')[-1].split('\\n')[0].split(',')

    with open(args.log_file_path, 'r') as log_file:
        results = [extract_values(x) for x in log_file.read().splitlines() if 'Sentry Benchmark' in x]

    def overhead(readings):
        """Given a set of readings for system and user time from profiler and app, compute the profiler's overhead."""
        return 100.0 * (int(readings[0]) + int(readings[1])) / (int(readings[2]) + int(readings[3]))

    percentages = [f'{y:.3f}' for y in sorted([overhead(x) for x in results])]
    count = len(percentages)

    middle_index = int(math.floor(count / 2))
    median = (float(percentages[middle_index - 1]) + float(percentages[middle_index])) / 2 if count % 2 == 0 else percentages[middle_index]

    mean = functools.reduce(lambda res, next: res + float(next), percentages, 0) / len(percentages)

    p90_index = math.ceil(len(percentages) * 0.9)
    p90 = percentages[p90_index - 1]

    print(f'''Benchmark report
----------------
All observations (overhead, %):
{percentages}

Median: {median:.3f}
Mean: {mean:.3f}
P90: {p90}
    ''')


if __name__ == '__main__':
    main()
