#!/usr/bin/env python3

import logging

from lib.format_helpers import bold, cyan

def error(message):
    logging.getLogger().error(message)

def warning(message):
    logging.getLogger().warning(message)

def info(message):
    logging.getLogger().info(message)

def debug(message):
    logging.getLogger().debug(message)

def format_logger():
    logging.basicConfig(level=logging.INFO, format=f"{bold(cyan('[sentry]'))} %(message)s")

def set_level(level):
    logging.getLogger().setLevel(level)
