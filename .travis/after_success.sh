#!/bin/sh
if [ "$LANE" = "test" ]; then bash <(curl -s https://codecov.io/bash) -J '^Swift$' elif [ "$LANE" = "test_swift" ]; then bash <(curl -s https://codecov.io/bash) -J '^SentrySwift$' fi
