#!/usr/bin/env python3

"""
Checks Objective-C header files for bare 'id' usage without SENTRY_SWIFT_MIGRATION_ID macro.

During Swift migration, bare 'id' types should be annotated with SENTRY_SWIFT_MIGRATION_ID(ClassName)
to track temporary workarounds and make them easy to find later.

This linter flags any 'id' usage in .h files that:
- Is not part of SENTRY_SWIFT_MIGRATION_ID macro
- Is not in a comment
- Does not have an inline comment explaining why bare 'id' is needed

Allowed patterns:
1. SENTRY_SWIFT_MIGRATION_ID(ClassName)
2. id someVar; // OK: explanation why bare id is needed
3. id someVar; /* OK: explanation */
"""

from __future__ import print_function, unicode_literals

import argparse
import fnmatch
import io
import os
import re
import sys

class ExitStatus:
    SUCCESS = 0
    VIOLATIONS_FOUND = 1
    TROUBLE = 2


def bold_red(s):
    return '\x1b[1m\x1b[31m' + s + '\x1b[0m'


def yellow(s):
    return '\x1b[33m' + s + '\x1b[0m'


def list_files(files, recursive=False, extensions=None, exclude=None):
    """List files matching the given extensions."""
    if extensions is None:
        extensions = []
    if exclude is None:
        exclude = []

    out = []
    for file in files:
        if recursive and os.path.isdir(file):
            for dirpath, dnames, fnames in os.walk(file):
                fpaths = [os.path.join(dirpath, fname) for fname in fnames]
                for pattern in exclude:
                    dnames[:] = [
                        x for x in dnames
                        if not fnmatch.fnmatch(os.path.join(dirpath, x), pattern)
                    ]
                    fpaths = [
                        x for x in fpaths if not fnmatch.fnmatch(x, pattern)
                    ]
                for f in fpaths:
                    ext = os.path.splitext(f)[1][1:]
                    if ext in extensions:
                        out.append(f)
        else:
            out.append(file)
    return out


def remove_comments(code):
    """Remove C-style comments from code, preserving line structure."""
    lines = code.split('\n')
    result_lines = []
    in_multiline_comment = False

    for line in lines:
        if in_multiline_comment:
            # Check if this line ends the multi-line comment
            end_pos = line.find('*/')
            if end_pos != -1:
                line = ' ' * (end_pos + 2) + line[end_pos + 2:]
                in_multiline_comment = False
            else:
                line = ' ' * len(line)
        else:
            # Remove single-line comments
            single_comment_pos = line.find('//')
            if single_comment_pos != -1:
                line = line[:single_comment_pos]

            # Check for start of multi-line comment
            start_pos = line.find('/*')
            if start_pos != -1:
                end_pos = line.find('*/', start_pos)
                if end_pos != -1:
                    # Comment starts and ends on same line
                    line = line[:start_pos] + ' ' * (end_pos + 2 - start_pos) + line[end_pos + 2:]
                else:
                    # Comment starts but doesn't end on this line
                    line = line[:start_pos]
                    in_multiline_comment = True

        result_lines.append(line)

    return '\n'.join(result_lines)


def has_inline_comment_exception(line):
    """Check if the line has an inline comment starting with 'OK:' explaining the bare id usage."""
    # Check for // OK: comment
    if re.search(r'//\s*OK:', line, re.IGNORECASE):
        return True
    # Check for /* OK: comment */
    if re.search(r'/\*\s*OK:.*?\*/', line, re.IGNORECASE):
        return True
    return False


def check_id_usage(file_path):
    """
    Check a single header file for bare 'id' usage.

    Returns a list of violations, where each violation is a tuple of (line_number, line_content).
    """
    violations = []

    try:
        with io.open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            lines = content.splitlines()
    except IOError as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return violations

    # Remove comments for main analysis, but keep original lines for inline comment check
    content_no_comments = remove_comments(content)
    lines_no_comments = content_no_comments.splitlines()

    # Pattern to match bare 'id' usage that should use SENTRY_SWIFT_MIGRATION_ID:
    # Match 'id' as a type in declarations:
    # - @property declarations: @property (nonatomic, strong) id variableName
    # - Parameter types in method signatures: - (void)method:(id)param
    # - Return types: - (id)method or + (id)method
    # - Instance variable declarations: id _ivar;
    #
    # Exclusions:
    # - id<Protocol> (protocol conformance) - these are acceptable
    # - String literals containing "id"
    # - Already using SENTRY_SWIFT_MIGRATION_ID
    # - initializers

    for line_num, (line, line_no_comment) in enumerate(zip(lines, lines_no_comments), start=1):
        # Skip empty lines or lines with only whitespace
        if not line_no_comment.strip():
            continue

        # Skip if SENTRY_SWIFT_MIGRATION_ID is already used on this line
        if 'SENTRY_SWIFT_MIGRATION_ID' in line_no_comment:
            continue

        # Skip if this is a string literal (rough check)
        if '"id"' in line_no_comment or "'id'" in line_no_comment:
            continue

        # Skip if this is id<Protocol> (protocol conformance)
        if re.search(r'\bid\s*<[^>]+>', line_no_comment):
            continue

        # Check for various patterns where bare 'id' is used as a type:

        # Pattern 1: @property declarations with bare id
        # @property (...) id propertyName
        if re.search(r'@property\s*\([^)]*\)\s*\bid\b(?!\s*<)', line_no_comment):
            if not has_inline_comment_exception(line):
                violations.append((line_num, line.rstrip()))
                continue

        # Pattern 2: Method return type: - (id)methodName or + (id)methodName
        # Skip init methods as returning id from init is idiomatic Objective-C
        if re.search(r'^[+-]\s*\(\s*\bid\b(?!\s*<)\s*\)', line_no_comment):
            # Check if this is an init method
            if not re.search(r'^[+-]\s*\(\s*id\s*\)\s*init', line_no_comment):
                if not has_inline_comment_exception(line):
                    violations.append((line_num, line.rstrip()))
                    continue

        # Pattern 3: Method parameter type: :(id)paramName or :(id *)paramName
        if re.search(r':\s*\(\s*\bid\b(?!\s*<)\s*\**\s*\)', line_no_comment):
            if not has_inline_comment_exception(line):
                violations.append((line_num, line.rstrip()))
                continue

        # Pattern 4: Instance variable declaration: id _variableName;
        # Be more conservative - only match instance variables (usually start with _)
        if re.search(r'^\s*\bid\b(?!\s*<)\s+_[a-zA-Z_][a-zA-Z0-9_]*\s*;', line_no_comment):
            if not has_inline_comment_exception(line):
                violations.append((line_num, line.rstrip()))
                continue

    return violations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '-r',
        '--recursive',
        action='store_true',
        help='run recursively over directories')
    parser.add_argument(
        'files',
        metavar='file',
        nargs='+',
        help='files or directories to check')
    parser.add_argument(
        '-q',
        '--quiet',
        action='store_true',
        help='disable output, useful for the exit code')
    parser.add_argument(
        '--color',
        default='auto',
        choices=['auto', 'always', 'never'],
        help='show colored output (default: auto)')
    parser.add_argument(
        '-e',
        '--exclude',
        metavar='PATTERN',
        action='append',
        default=[],
        help='exclude paths matching the given glob-like pattern(s) from recursive search')

    args = parser.parse_args()

    # Determine color usage
    use_color = False
    if args.color == 'always':
        use_color = True
    elif args.color == 'auto':
        use_color = sys.stdout.isatty()

    # Only check .h files
    extensions = ['h']

    files = list_files(
        args.files,
        recursive=args.recursive,
        exclude=args.exclude,
        extensions=extensions)

    if not files:
        return ExitStatus.SUCCESS

    total_violations = 0

    for file_path in files:
        violations = check_id_usage(file_path)

        if violations:
            total_violations += len(violations)

            if not args.quiet:
                # Print file header
                error_text = 'Bare id usage found:'
                if use_color:
                    error_text = bold_red(error_text)
                print(f"\n{error_text} {file_path}")

                # Print violations
                for line_num, line_content in violations:
                    if use_color:
                        print(f"  {yellow(f'Line {line_num}:')} {line_content}")
                    else:
                        print(f"  Line {line_num}: {line_content}")

    if total_violations > 0 and not args.quiet:
        print(f"\n{'=' * 80}")
        violation_text = f"Found {total_violations} bare 'id' usage(s)"
        if use_color:
            violation_text = bold_red(violation_text)
        print(violation_text)
        print("\nTo fix:")
        print("1. Use SENTRY_SWIFT_MIGRATION_ID(ClassName) to track temporary workarounds")
        print("2. Or add inline comment: // OK: explanation why bare id is needed")
        print("3. Or add inline comment: /* OK: explanation */")
        return ExitStatus.VIOLATIONS_FOUND

    return ExitStatus.SUCCESS


if __name__ == '__main__':
    sys.exit(main())
