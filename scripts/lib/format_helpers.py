#!/usr/bin/env python3

from lib.xcode_helpers import is_xcode

class fmt:
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    DARKCYAN = '\033[36m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

def purple(message):
    return applied(message, fmt.PURPLE)

def cyan(message):
    return applied(message, fmt.CYAN)

def dark_cyan(message):
    return applied(message, fmt.DARKCYAN)

def blue(message):
    return applied(message, fmt.BLUE)

def green(message):
    return applied(message, fmt.GREEN)

def yellow(message):
    return applied(message, fmt.YELLOW)

def red(message):
    return applied(message, fmt.RED)

def underline(message):
    return applied(message, fmt.UNDERLINE)

def bold(message):
    return applied(message, fmt.BOLD)

def applied(message, format):
    if is_xcode():
        return message  # avoid showing all the raw format characters in the logs
    else:
        return f'{format}{message}{fmt.END}'
