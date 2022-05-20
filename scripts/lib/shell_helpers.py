#!/usr/bin/env python3

import subprocess

from lib.environment_helpers import is_github_action
from lib.logging_helpers import debug

def shell(command):
    '''Execute a string as a shell command with subprocess'''
    debug(f'Executing shell command: {command}')
    result = subprocess.check_call(command, shell=True)
    debug(f'{result=}')
    return result

def shell_output(command, suppress_stderr=False):
    debug(f'Retrieving output from shell command: {command}')
    if suppress_stderr:
        result = subprocess.check_output(command, encoding="utf-8", shell=True, stderr=subprocess.DEVNULL).strip()
    else:
        result = subprocess.check_output(command, encoding="utf-8", shell=True).strip()
    debug(f'{result=}')
    return result

def call(args, cwd=None, env=None):
    '''Execute a an array of shell arguments with subprocess'''
    debug(f'Executing command args: {args} in cwd {cwd}')
    subprocess.check_call(args, cwd=cwd, env=env)

def call_output(args, cwd=None):
    '''Execute a an array of shell arguments with subprocess and retrieve the output'''
    debug(f'Retrieving output from args: {args} in cwd {cwd}')
    result = subprocess.check_output(args, encoding="utf-8", cwd=cwd).strip()
    debug(f'{result=}')
    return result

def rbenv_args(args):
    if is_github_action():
        all_args = args
    else:
        all_args = ['rbenv', 'exec'] + args
    return all_args

def bundled_args(gem_args):
    return rbenv_args(['bundle', 'exec'] + gem_args)
