#!/usr/bin/env python3

import os

def is_xcode():
    '''Return True if this process was spawned from an Xcode Run Script Build Phase.'''
    return os.getenv('XCODE_VERSION_ACTUAL')
