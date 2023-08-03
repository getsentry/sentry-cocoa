#!/bin/bash
set -euxo pipefail

PLATFORM="${1:-ios}"
POD_SPEC=${2:-Sentry}
LIBRARY_TYPE="${3:-dynamic}"
INCLUDE_POD_SPECS=""
EXTRA_ARGS=""

case $POD_SPEC in

"Sentry")
    INCLUDE_POD_SPECS="--include-podspecs=SentryPrivate.podspec"
    ;;

"SentrySwiftUI")
    INCLUDE_POD_SPECS="--include-podspecs={Sentry.podspec,SentryPrivate.podspec}"
    ;;

*)
    echo "pod lib lint: Can't find --include-podspecs for '$POD_SPEC'"
    exit 1
    ;;
esac

case $LIBRARY_TYPE in
"static")
    EXTRA_ARGS="--use-libraries"
    ;;

*)
    EXTRA_ARGS=""
    ;;
esac

pod lib lint --verbose --platforms="$PLATFORM" "$POD_SPEC".podspec "$INCLUDE_POD_SPECS" $EXTRA_ARGS
