#!/bin/sh

cd ~
git clone https://github.com/getsentry/sentry-cli.git
cd sentry-cli
git checkout szokeasaurusrex/check-revert-optimizations
cargo build --release
