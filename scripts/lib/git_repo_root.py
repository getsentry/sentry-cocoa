#!/usr/bin/env python3

import subprocess

git_repo_root = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], encoding='utf-8').strip()
