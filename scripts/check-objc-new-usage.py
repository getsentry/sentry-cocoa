#!/usr/bin/env python3

# Checks Objective-C files for usage of [ClassName new] which is dangerous and
# should be replaced with [[ClassName alloc] init].
#
# See: https://blog.cristik.com/2018/02/objective-c-new-is-dangerous-and-old-avoid-it-at-all-costs/
# See: https://github.com/getsentry/sentry-cocoa/pull/1969#discussion_r957770700

from __future__ import print_function, unicode_literals

import argparse
import fnmatch
import io
import os
import re
import sys

# Pattern matches [ClassName new] or [ClassName<Generics> new]
# Class name cannot contain [ or ] (brackets only appear in message send syntax)
OBJC_NEW_PATTERN = re.compile(r'\[([^[\]]+)\s+new\]')


def list_files(files, recursive=False, extensions=None, exclude=None):
    if extensions is None:
        extensions = []
    if exclude is None:
        exclude = []

    out = []
    for file in files:
        if recursive and os.path.isdir(file):
            for dirpath, dnames, fnames in os.walk(file):
                dnames[:] = [
                    x for x in dnames
                    if not any(
                        fnmatch.fnmatch(os.path.join(dirpath, x), p)
                        for p in exclude
                    )
                ]
                for fname in fnames:
                    fpath = os.path.join(dirpath, fname)
                    if any(fnmatch.fnmatch(fpath, p) for p in exclude):
                        continue
                    ext = os.path.splitext(fpath)[1][1:]
                    if ext in extensions:
                        out.append(fpath)
        else:
            out.append(file)
    return out


def remove_comments(line):
    """Remove // and /* */ comments from a line for analysis."""
    result = []
    i = 0
    in_string = False
    string_char = None
    in_block_comment = False

    while i < len(line):
        if in_block_comment:
            if i < len(line) - 1 and line[i:i + 2] == '*/':
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_string:
            if line[i] == '\\' and i + 1 < len(line):
                i += 2
                continue
            if line[i] == string_char:
                in_string = False
            result.append(line[i])
            i += 1
            continue

        if line[i] in '"\'':
            in_string = True
            string_char = line[i]
            result.append(line[i])
            i += 1
            continue

        if i < len(line) - 1 and line[i:i + 2] == '//':
            break  # Rest of line is comment
        if i < len(line) - 1 and line[i:i + 2] == '/*':
            in_block_comment = True
            i += 2
            continue

        result.append(line[i])
        i += 1

    return ''.join(result)


def fix_line(line):
    """Replace [ClassName new] with [[ClassName alloc] init] in a line."""
    return OBJC_NEW_PATTERN.sub(r'[[\1 alloc] init]', line)


def check_file(file_path, fix=False):
    """
    Check a single file for [ClassName new] usage.
    Returns (violations, modified_content).
    violations: list of (line_num, line_content)
    modified_content: new file content if fix=True and changes were made, else None
    """
    violations = []

    try:
        with io.open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except (IOError, OSError) as e:
        print("Error reading {}: {}".format(file_path, e), file=sys.stderr)
        return violations, None

    modified_lines = []
    has_changes = False

    for idx, line in enumerate(lines):
        line_num = idx + 1
        line_no_comments = remove_comments(line)

        if OBJC_NEW_PATTERN.search(line_no_comments):
            violations.append((line_num, line.rstrip()))
            if fix:
                new_line = fix_line(line)
                if new_line != line:
                    modified_lines.append(new_line)
                    has_changes = True
                else:
                    modified_lines.append(line)
            else:
                modified_lines.append(line)
        else:
            modified_lines.append(line)

    modified_content = None
    if fix and has_changes:
        modified_content = ''.join(modified_lines)

    return violations, modified_content


def bold_red(s):
    return '\x1b[1m\x1b[31m' + s + '\x1b[0m'


def yellow(s):
    return '\x1b[33m' + s + '\x1b[0m'


def main():
    parser = argparse.ArgumentParser(
        description='Check Objective-C files for [ClassName new] usage. '
        'Use [ClassName alloc] init] instead.')
    parser.add_argument(
        '-r', '--recursive',
        action='store_true',
        help='Run recursively over directories')
    parser.add_argument(
        '--fix',
        action='store_true',
        help='Fix violations by replacing with [[ClassName alloc] init]')
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Disable output, useful for the exit code')
    parser.add_argument(
        '-e', '--exclude',
        metavar='PATTERN',
        action='append',
        default=[],
        help='Exclude paths matching the given glob-like pattern(s)')
    parser.add_argument(
        'files',
        metavar='file',
        nargs='+',
        help='Files or directories to check')

    args = parser.parse_args()

    extensions = ['m', 'mm']
    exclude = args.exclude
    exclude.extend([
        '**/Pods/**',
        '**/build/**',
        '**/.build/**',
        '**/Build/**',
    ])

    files = list_files(
        args.files,
        recursive=args.recursive,
        extensions=extensions,
        exclude=exclude)

    if not files:
        return 0

    total_violations = 0
    files_to_write = []

    for file_path in files:
        violations, modified_content = check_file(file_path, fix=args.fix)

        if violations:
            total_violations += len(violations)

            if not args.quiet:
                error_text = 'ObjC [new] usage found:'
                if sys.stdout.isatty():
                    error_text = bold_red(error_text)
                print("\n{} {}".format(error_text, file_path))

                for line_num, line_content in violations:
                    if sys.stdout.isatty():
                        print("  {}: {}".format(
                            yellow("Line {}".format(line_num)), line_content))
                    else:
                        print("  Line {}: {}".format(line_num, line_content))

            if modified_content is not None:
                files_to_write.append((file_path, modified_content))

    # Write fixes
    for file_path, content in files_to_write:
        try:
            with io.open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            if not args.quiet:
                print("Fixed: {}".format(file_path))
        except (IOError, OSError) as e:
            print("Error writing {}: {}".format(file_path, e), file=sys.stderr)
            return 2

    if total_violations > 0:
        if not args.quiet:
            print("\n" + "=" * 80)
            violation_text = "Found {} [ClassName new] usage(s)".format(
                total_violations)
            if sys.stdout.isatty():
                violation_text = bold_red(violation_text)
            print(violation_text)
            if not args.fix:
                print("\nTo fix: run with --fix or use 'make format-objc-new'")
        # When --fix was used and we successfully fixed all, return 0
        if args.fix and files_to_write:
            return 0
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
