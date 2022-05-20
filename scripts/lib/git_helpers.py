#!/usr/bin/env python3

import os
import sys

from lib.environment_helpers import is_github_action
from lib.logging_helpers import error, info
from lib.shell_helpers import call, call_output, shell, shell_output

git_repo_root = call_output(["git", "rev-parse", "--show-toplevel"])

def git_clean_index():
    call(['git', 'checkout', '.'])

def git_commit(message, all=False):
    args = ['git', 'commit', '--message', message]
    if all:
        args.append('--all')
    call(args)

def git_commit_hash():
    return call_output(['git', 'rev-parse', '--short', 'HEAD'])

def git_tag(tag):
    call(['git', 'tag', tag])

def git_cherry_pick(commit_hash, keep_redundant_commits=False, merge_with_theirs=False):
    args = ['git', 'cherry-pick']
    if keep_redundant_commits:
        args.append('--keep-redundant-commits')
    if merge_with_theirs:
        args.append('-Xtheirs')
    args.append(commit_hash)
    call(args)

def git_fetch(tags=False, prune=False, prune_tags=False):
    args = ['git', 'fetch']
    if tags:
        args.append('--tags')
    if prune:
        args.append('--prune')
    if prune_tags:
        args.append('--prune-tags')
    call(args)

def git_checkout(name, new=False, remote_name=None):
    args = ['git', 'checkout']
    if new:
        args.append('-b')
    args.append(name)
    if remote_name is not None:
        args.append(f'origin/{remote_name}')
    call(args)

def git_pull(rebase=False, remote_name=None):
    args = ['git', 'pull']
    if rebase:
        args.append('--rebase')
    if remote_name is not None:
        args.append()
    call(args)

def git_push(tags=False, branch=True):
    if branch:
        call(['git', 'push'])
    if tags:
        call(['git', 'push', '--tags'])

def git_push_new(name):
    call(['git', 'push', 'origin', f'HEAD:{name}'])

def git_deploy_checks():
    if not is_github_action():
        git_check_clean_index()

def git_check_clean_index():
    try:
        shell(['git status | grep "nothing to commit, working tree clean"'])
    except:
        error('you have uncommited changes, unable to do release work')
        sys.exit(65)

def git_cherry_pick_to_master(commit_hash):
    git_checkout('master')
    git_fetch()
    git_pull(rebase=True)
    git_cherry_pick(commit_hash, keep_redundant_commits=True, merge_with_theirs=True)

class git_labels:
    IOS = 'iOS'

def git_open_pr(labels = []):
    args = ['gh', 'pr', 'create', '--web', '--label']
    if len(labels) > 0:
        args.extend(labels)
    call(args)

class git_temp_branch():
    def __init__(self, name):
        self.name = name

    def __enter__(self):
        self.previous = git_temp_start(self.name)

    def __exit__(self, exc_type, exc_val, exc_tb):
        git_temp_end(self.previous)

def git_temp_start(name):
    '''Move to a new temporary branch and return name of old branch'''
    # delete any previous work branch
    if int(shell_output(f'git branch | grep {name} | wc -l')) > 0:
        call(['git', 'branch', '-D', name])

    # create a fresh work branch
    previous_branch_name = call_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
    info(f'currently on branch {previous_branch_name}; will work on a temporary branch called {name}')
    call(['git', 'checkout', '-b', name])
    return previous_branch_name

def git_temp_end(previous_branch_name):
    '''Move back to previous branch and delete the temp branch.'''
    info(f'cleaning up temporary git branch, going back to {previous_branch_name}')
    current_branch_name = call_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
    call(['git', 'checkout', previous_branch_name])
    call(['git', 'branch', '-D', current_branch_name])
