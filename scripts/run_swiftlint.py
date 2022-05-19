#!/usr/bin/env python3

import os
import sys
from lib.git_repo_root import git_repo_root
from lib.swiftlint_git_diff import get_swiftlint_issues_in_diff

if 'XCODE_PRODUCT_BUILD_VERSION' in os.environ and 'CI' in os.environ:
    print('Will not run swiftlint as a build phase for this target in CI via Xcode. It will run in a dedicated GitHub action workflow separately.')
    sys.exit(0)

get_swiftlint_issues_in_diff()
