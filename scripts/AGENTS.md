# Scripts

> Scope: `scripts/**`. Also follow [root instructions](../AGENTS.md).

## Shell Scripts

- New scripts must use named `--kebab-case` parameters, not positional parameters
- Start scripts with `set -euo pipefail`
- Declare defaults before `usage()` and validate required parameters after parsing
- Document every parameter in `usage()`
- Source `ci-utils.sh` for CI logging
- Avoid complex heredocs and move substantial logic into an appropriate standalone script
- Follow `scripts/sentry-xcodebuild.sh` as the named-parameter reference

### Template

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-utils.sh
source "$SCRIPT_DIR/ci-utils.sh"

PARAM_ONE=""
PARAM_TWO="default-value"

usage() {
    log_notice "Usage: $0"
    log_notice "  --param-one <value>    Description of param one (required)"
    log_notice "  --param-two <value>    Description of param two (default: default-value)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --param-one) PARAM_ONE="$2"; shift 2 ;;
        --param-two) PARAM_TWO="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [ -z "$PARAM_ONE" ]; then
    log_error "Error: --param-one is required"
    usage
fi
```

## Legacy Scripts

- Do not migrate unrelated positional arguments while making a focused change
- Migrate a legacy script to named parameters only when required by the requested change
