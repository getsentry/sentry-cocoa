#!/bin/bash
#
# Analyzes the repository's language breakdown using github-linguist (the same
# tool GitHub uses). Produces an interactive HTML line chart showing monthly
# trends, split by Sources/, Tests/, and Overall.
#
# Usage: ./scripts/analyze-languages/analyze-languages.sh [--since YYYY-MM-DD]
#        or: make analyze-languages [SINCE=YYYY-MM-DD]
#
# Options:
#   --since YYYY-MM-DD   How far back to analyze (default: 2019-01-01)
#
# Requirements: Ruby + Bundler (ships with macOS), Python 3 (ships with macOS)
# Output: language-trends.html (opened automatically in the default browser)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Source CI utility functions for logging and grouping
# shellcheck source=./scripts/ci-utils.sh disable=SC1091
source "${REPO_ROOT}/scripts/ci-utils.sh"

# Verify prerequisites
command -v ruby &> /dev/null || { log_error "Ruby is required but not installed"; exit 1; }
command -v bundle &> /dev/null || { log_error "Bundler is required but not installed"; exit 1; }
command -v python3 &> /dev/null || { log_error "Python 3 is required but not installed"; exit 1; }

export BUNDLE_GEMFILE="$SCRIPT_DIR/Gemfile"
OUTPUT_FILE="$REPO_ROOT/language-trends.html"
DATA_DIR="$(mktemp -d)"
export DATA_DIR OUTPUT_FILE
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
# In CI, actions/checkout only creates the triggering branch locally;
# other branches exist only as remote refs.
if ! git show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
    DEFAULT_BRANCH="origin/$DEFAULT_BRANCH"
fi

# ── Cleanup on exit (remove temporary data directory) ─────────────────────
cleanup() {
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
    fi
}
trap cleanup EXIT

# ── 1. Set up github-linguist via Bundler ─────────────────────────────────
begin_group "Setting up github-linguist"

# Install gems if not already installed (e.g., local development).
# In CI, bundle install is handled by the workflow before this script runs.
if ! bundle check > /dev/null 2>&1; then
    log_notice "Running bundle install for linguist"
    bundle install
fi

# Verify it works
bundle exec github-linguist --version > /dev/null 2>&1 || {
    log_error "github-linguist not available via bundle exec"
    exit 1
}
end_group

# ── 2. Parse named arguments ──────────────────────────────────────────────
SINCE_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --since)
            SINCE_ARG="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1. Usage: $0 [--since YYYY-MM-DD]"
            exit 1
            ;;
    esac
done

# ── 3. Find one commit per month for the analysis range ──────────────────
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%-m)

if [ -n "$SINCE_ARG" ]; then
    # Validate YYYY-MM-DD format
    if ! [[ "$SINCE_ARG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_error "Date must be in YYYY-MM-DD format (got: $SINCE_ARG)"
        exit 1
    fi
    START_YEAR="${SINCE_ARG%%-*}"
    START_MONTH="$(echo "$SINCE_ARG" | cut -d- -f2)"
    START_MONTH=$((10#$START_MONTH))
    log_notice "Finding monthly commits since $SINCE_ARG"
else
    # Default: start from January 2019. Before that, the language stats
    # fluctuate significantly between months, making the chart unreliable.
    START_YEAR=2019
    START_MONTH=1
    log_notice "Finding monthly commits since January 2019"
fi

COMMITS=()
MONTHS=()

for year in $(seq "$START_YEAR" "$CURRENT_YEAR"); do
    for month in $(seq -w 1 12); do
        # Stop after current month
        if [ "$year" -eq "$CURRENT_YEAR" ] && [ "$((10#$month))" -gt "$CURRENT_MONTH" ]; then
            break
        fi
        # Skip months before start
        if [ "$year" -eq "$START_YEAR" ] && [ "$((10#$month))" -lt "$START_MONTH" ]; then
            continue
        fi

        commit=$(git log "$DEFAULT_BRANCH" --before="${year}-${month}-15" --after="${year}-${month}-01" -1 --format="%H" 2>/dev/null || true)
        if [ -z "$commit" ]; then
            commit=$(git log "$DEFAULT_BRANCH" --before="${year}-${month}-28" --after="${year}-${month}-01" -1 --format="%H" 2>/dev/null || true)
        fi

        if [ -n "$commit" ]; then
            MONTHS+=("${year}-${month}")
            COMMITS+=("$commit")
        fi
    done
done

TOTAL=${#COMMITS[@]}

if [ "$TOTAL" -eq 0 ]; then
    log_error "No commits found in the requested date range. Check your SINCE date or branch history."
    exit 1
fi

# ── 4. Run linguist + git ls-tree on each revision ───────────────────────
begin_group "Analyzing $TOTAL revisions"
for i in $(seq 0 $((TOTAL - 1))); do
    month="${MONTHS[$i]}"
    sha="${COMMITS[$i]}"
    log_notice "[$((i + 1))/$TOTAL] $month"
    bundle exec github-linguist --rev "$sha" --breakdown --json > "$DATA_DIR/${month}.linguist.json" 2>/dev/null
    git ls-tree -r -l "$sha" > "$DATA_DIR/${month}.lstree.txt"
done
end_group

# ── 5. Generate the HTML chart using Python ───────────────────────────────
begin_group "Generating chart"
python3 "$SCRIPT_DIR/generate-chart.py" --data-dir "$DATA_DIR" --output-file "$OUTPUT_FILE"

log_notice "Chart written to $OUTPUT_FILE"
end_group

# ── 6. Open in browser ───────────────────────────────────────────────────
if [ "${CI:-}" != "true" ]; then
    if command -v open &> /dev/null; then
        open "$OUTPUT_FILE"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$OUTPUT_FILE"
    fi
fi

log_notice "Done!"
