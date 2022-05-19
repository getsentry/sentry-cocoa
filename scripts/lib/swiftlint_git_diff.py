#!/usr/bin/env python3

import os
import re
import subprocess
import sys
from lib.git_repo_root import git_repo_root

def get_swiftlint_issues_in_diff():
    def get_git_diff():
        "Filter some git-diff output to get the line number ranges of additions to each modified file."
        diff = subprocess.check_output(['git', 'diff', '--diff-filter=AM', '-U0'], encoding='utf-8').strip().split('\n')

        # find every instance of the string "diff --git a/... b/...", as this separates hunks in the diff output

        filename_regex = '^diff \-\-git a/(.*) b/(.*)'
        hunk_indices = [diff.index(x) for x in diff if re.match(filename_regex, x)]

        if len(hunk_indices) == 0:
            return {}

        changes_regex = '^@@ -.* \+(\d*),?(\d*)? @@'
        def get_line_change_specs(query):
            "Grab the new line specs from a file's git-diff header."
            result = re.search(changes_regex, query)
            starting_line = result.group(1)
            if len(result.groups()) > 1:
                range_length = result.group(2)
                return (starting_line, range_length)
            else:
                return (starting_line, None)

        def get_filename(query):
            "Grab the filename from a file's git-diff header."
            result = re.search(filename_regex, query)
            return result.group(1)

        def get_changes_in_file_hunk(i):
            "Given an index for a hunk in a file, retrieve the line number range of additions, along with the filename."
            filename = get_filename(diff[hunk_indices[i]])
            if i == -1:
                lines = diff[hunk_indices[-1]:]
            else:
                lines = diff[hunk_indices[i]:hunk_indices[i+1] - 1]
            changes = [get_line_change_specs(x) for x in lines if re.match(changes_regex, x)]
            return (filename, changes)

        all_changes = {}
        # for each file's diff lines, grab the line change specs
        for i in range(0, len(hunk_indices) - 1):
            mapping = get_changes_in_file_hunk(i)
            all_changes[mapping[0]] = mapping[1]

        mapping = get_changes_in_file_hunk(-1)
        all_changes[mapping[0]] = mapping[1]

        return all_changes

    def get_swiftlint_report():
        "Run swiftlint, return its status code and an array of all the issues it produced."
        swiftlint_path = "swiftlint"
        if os.path.exists("/usr/local/bin/swiftlint"):
            swiftlint_path = "/usr/local/bin/swiftlint"
        elif os.path.exists("/opt/homebrew/bin/swiftlint"):
            swiftlint_path = "/opt/homebrew/bin/swiftlint"
        process = subprocess.Popen([swiftlint_path], encoding='utf-8', stderr=subprocess.DEVNULL, stdout=subprocess.PIPE, cwd=git_repo_root)
        out, err = process.communicate()
        status = process.returncode
        return (status, [x for x in out.strip().split('\n') if 'Carthage' not in x and ('warning:' in x or 'error:' in x)])

    def is_swiftlint_issue_in_git_diff(issue):
        "Given one issue from swiftlint, see if that file/line appears in any of the git diffs we processed earlier."
        # example:
        # /Users/andrewmcknight/Code/organization/getsentry/repos/public/sentry-cocoa/Tests/SentryTests/SentrySDKTests.swift:569:13: warning: Identifier Name Violation: Variable name should be between 2 and 40 characters long: 'i' (identifier_name)
        regex = f'^{git_repo_root}/(.*):(\d*):\d*: .*'
        result = re.match(regex, issue)
        filename = result.group(1)
        line_number = result.group(2)

        if filename not in git_changes:
            return False

        relevant_changes = git_changes[filename]

        def line_number_lies_in_range(line, range):
            "Return True if the issue's line number is located inside the line number range specified in some diff hunk."
            if range[1] == '':
                return int(line) == int(range[0])
            else:
                return int(line) >= int(range[0]) and int(line) < int(range[0]) + int(range[1])

        relevant_hunks = [x for x in relevant_changes if line_number_lies_in_range(line_number, x)]
        return len(relevant_hunks) > 0

    git_changes = get_git_diff()
    if len(git_changes) == 0:
        sys.exit(0)

    swiftlint_report = get_swiftlint_report()
    if len(swiftlint_report[1]) == 0:
        sys.exit(swiftlint_report[0])

    relevant_swiftlint_issues = [x for x in swiftlint_report[1] if is_swiftlint_issue_in_git_diff(x)]
    if len(relevant_swiftlint_issues) == 0:
        sys.exit(0)

    for issue in relevant_swiftlint_issues:
        print(issue)

    sys.exit(swiftlint_report[0])
