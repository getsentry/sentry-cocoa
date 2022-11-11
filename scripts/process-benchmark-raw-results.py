#!/usr/bin/env python3

import argparse
import functools
import math
import matplotlib.pyplot as plt
import subprocess
import sys

"""A script to parse an XCUITest console log, extract raw benchmark values, and statistically analyze the SDK profiler's CPU overhead."""

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log_file_path', help='Path to the log file to parse.')
    parser.add_argument('device_class', help='The class of device the benchmarks were run on.')
    parser.add_argument('device_name', help='The name of the actual device the benchmarks were run on.')
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
    percentage_values = [y for y in sorted([overhead(x) for x in results])]
    count = len(percentages)

    middle_index = int(math.floor(count / 2))
    median = (float(percentages[middle_index - 1]) + float(percentages[middle_index])) / 2 if count % 2 == 0 else percentages[middle_index]

    mean = functools.reduce(lambda res, next: res + float(next), percentages, 0) / len(percentages)

    p0 = percentages[0]
    p0_value = percentage_values[0]

    p90_index = math.ceil(len(percentages) * 0.9)
    p90 = percentages[p90_index - 1]
    p90_value = percentage_values[p90_index - 1]

    p99_index = math.ceil(len(percentages) * 0.99)
    p99 = percentages[p99_index - 1]
    p99_value = percentage_values[p99_index - 1]

    p99_9_index = math.ceil(len(percentages) * 0.999)
    p99_9 = percentages[p99_9_index - 1]
    p99_9_value = percentage_values[p99_9_index - 1]

    p99_999_index = math.ceil(len(percentages) * 0.99999)
    p99_999 = percentages[p99_999_index - 1]
    p99_999_value = percentage_values[p99_999_index - 1]

    p99_99999_index = math.ceil(len(percentages) * 0.9999999)
    p99_99999 = percentages[p99_99999_index - 1]
    p99_99999_value = percentage_values[p99_99999_index - 1]

    print(f'''Benchmark report
----------------
All observations (overhead, %):
{percentages}

Median: {median:.3f}
Mean: {mean:.3f}
P0: {p0}
P90: {p90}
P99: {p99}
P99.9: {p99_9}
P99.999: {p99_999}
P99.99999: {p99_99999}
    ''')

    percentiles = [p0_value, p90_value, p99_value, p99_9_value, p99_999_value, p99_99999_value]
    print(f"{percentiles=}")
    plt.title(f'Cpu time increase percentage for {args.device_class} devices (run on {args.device_name})')
    plt.plot(percentiles, marker='o')
    plt.ylabel('Cpu time increase %')
    plt.xlabel('Percentile')
    plt.xticks(ticks=[0, 1, 2, 3, 4, 5], labels=['0%', '90%', '99%', '99.9%', '99.999%', '99.99999%'])
    plt.grid(True)
    filename = f'ios_benchmarks_{args.device_class}_{args.device_name}.png'
    plt.savefig(filename)
    subprocess.check_call(['open', filename])

if __name__ == '__main__':
    main()
