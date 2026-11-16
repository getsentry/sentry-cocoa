#!/bin/bash
set -euo pipefail

# Installs the Ruby from .ruby-version with rbenv and runs bundle install.
# Only for Bitrise runners: ruby/setup-ruby doesn't work there, so jobs on
# GitHub-hosted runners use ruby/setup-ruby instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh disable=SC1091
source "$SCRIPT_DIR/ci-utils.sh"

CACHE_HIT="false"

usage() {
    log_info "Usage: $0"
    log_info "  -c, --cache-hit <true|false>    Whether the rbenv cache was restored (default: false)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cache-hit) CACHE_HIT="$2"; shift 2 ;;
        *) usage ;;
    esac
done

# Only touch Homebrew / build Ruby when the cache missed.
if [ "$CACHE_HIT" != "true" ]; then
    brew upgrade ruby-build
    # Link against the image's openssl@3. Upgrading ruby-build pulls in
    # openssl@4, but cache-hit runners skip that upgrade, so a Ruby
    # linked against openssl@4 fails to load openssl from the cache.
    OPENSSL_DIR="$(brew --prefix openssl@3)"
    RUBY_CONFIGURE_OPTS="--with-openssl-dir=$OPENSSL_DIR" rbenv install -s
else
    log_info "Ruby cache hit — skipping brew upgrade ruby-build and rbenv install"
    rbenv rehash
fi
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_LIBRARY_VERSION'
bundle install
