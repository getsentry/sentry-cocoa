# scripts

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## New Scripts

All new scripts **must** use named parameters. Positional parameters (`$1`, `$2`) are not allowed.

### Template

```bash
#!/bin/bash
set -euo pipefail

# Parse named arguments
PARAM_ONE=""
PARAM_TWO="default-value"

usage() {
    echo "Usage: $0"
    echo "  --param-one <value>    Description of param one (required)"
    echo "  --param-two <value>    Description of param two (default: default-value)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --param-one)  PARAM_ONE="$2";  shift 2 ;;
        --param-two)  PARAM_TWO="$2";  shift 2 ;;
        *)            usage ;;
    esac
done

if [ -z "$PARAM_ONE" ]; then
    echo "Error: --param-one is required"
    usage
fi
```

### Conventions

- `set -euo pipefail` at the top
- Declare all parameters with defaults before `usage()`
- Validate required parameters after parsing
- Use `--kebab-case` for flag names
- Include a `usage()` function that documents every parameter
- Extract complex logic into separate scripts (e.g., Python) rather than heredocs

### Reference

See `sentry-xcodebuild.sh` for a complete example of named parameter parsing. For CI logging (grouping, notices, warnings), source `ci-utils.sh` so output works properly in GitHub Actions.

### Legacy

Some older scripts still use positional parameters (e.g., `build-xcframework-slice.sh`). When modifying these, migrate to named parameters if the change scope allows.
