#!/usr/bin/env python3

import os

def is_github_action():
    '''Looks for a default GitHub Actions environment variable: https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables'''
    return os.environ.get('CI')
