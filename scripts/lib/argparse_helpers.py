#!/usr/bin/env python3

import argparse
import logging

from lib.logging_helpers import set_level, format_logger

def resolve_arguments_with_all_option(arg, available_options):
    '''For options that can have multiple values, or an 'all' value representing the whole set, return the list of actual options to use.'''
    if 'all' in arg:
        resolved = available_options
    elif isinstance(arg, list):
        resolved = arg
    else:
        resolved = [arg]
    return resolved

def parse_args(prog, docs, builder=None):
    '''Create an argument parser with an automatic verbosity option, parse the options described in a builder function, and return the supplied arguments.'''
    parser = argparse.ArgumentParser(prog=prog, description=docs, formatter_class=argparse.RawDescriptionHelpFormatter)
    if builder is not None:
        builder(parser)
    parser.add_argument('-v', '--verbose', help='Show debugging logs.', default=False, action='store_true')
    args = parser.parse_args()
    format_logger()
    if args.verbose:
        set_level(logging.DEBUG)
    return args

def add_boolean_option(self, name, help):
    '''Adds an option flag representing a toggle.'''
    self.add_argument(name, help=help, action="store_true")

def add_string_option(self, name, help=None, choices=None):
    '''Adds an option flag accepting a string value.'''
    self.add_argument(name, help=help, type=str, choices=choices)

def add_multivalued_option(self, name, help, choices, default='all'):
    '''Add option that accepts on of a set of choices that can also accept an "all" option (which can then be resolved into actual options using `resolve_arguments_with_all_option`). A default choice can be specified, and if none is, "all" is the default option.'''
    self.add_argument(name, help=help, default=default, choices=choices + ['all'])

argparse.ArgumentParser.add_boolean_option = add_boolean_option
argparse.ArgumentParser.add_multivalued_option = add_multivalued_option
argparse.ArgumentParser.add_string_option = add_string_option
