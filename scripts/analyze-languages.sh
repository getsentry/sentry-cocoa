#!/bin/bash
#
# Analyzes the repository's language breakdown using github-linguist (the same
# tool GitHub uses). Produces an interactive HTML line chart showing monthly
# trends, split by Sources/, Tests/, and Overall.
#
# Usage: ./scripts/analyze-languages.sh [YYYY-MM-DD]
#        or: make analyze-languages [SINCE=YYYY-MM-DD]
#
# The optional date argument sets how far back to analyze. Defaults to 5 years.
#
# Requirements: Ruby (ships with macOS), Python 3 (ships with macOS)
# Output: language-trends.html (opened automatically in the default browser)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Verify prerequisites
command -v ruby &> /dev/null || { echo "ERROR: Ruby is required but not installed"; exit 1; }
command -v gem &> /dev/null || { echo "ERROR: RubyGems is required but not installed"; exit 1; }
command -v python3 &> /dev/null || { echo "ERROR: Python 3 is required but not installed"; exit 1; }

TMP_DIR="$REPO_ROOT/_linguist_tmp"
OUTPUT_FILE="$REPO_ROOT/language-trends.html"
DATA_DIR="$TMP_DIR/data"
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
# In CI, actions/checkout only creates the triggering branch locally;
# other branches exist only as remote refs.
if ! git show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
    DEFAULT_BRANCH="origin/$DEFAULT_BRANCH"
fi

# ── Cleanup on exit (always remove the temp gem directory) ────────────────
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        echo "--> Cleaning up temporary linguist installation"
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# ── 1. Install github-linguist into a temporary directory ─────────────────
echo "--> Installing github-linguist gem (temporary, will be removed after)"
mkdir -p "$TMP_DIR" "$DATA_DIR"
GEM_HOME="$TMP_DIR" gem install github-linguist --no-document 2>&1 | tail -1

export GEM_HOME="$TMP_DIR"
export PATH="$TMP_DIR/bin:$PATH"

# Verify it works
github-linguist --version > /dev/null 2>&1 || {
    echo "ERROR: github-linguist installation failed"
    exit 1
}

# ── 2. Find one commit per month for the analysis range ──────────────────
SINCE_ARG="${1:-}"
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%-m)

if [ -n "$SINCE_ARG" ]; then
    # Validate YYYY-MM-DD format
    if ! [[ "$SINCE_ARG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "ERROR: Date must be in YYYY-MM-DD format (got: $SINCE_ARG)"
        exit 1
    fi
    START_YEAR="${SINCE_ARG%%-*}"
    START_MONTH="$(echo "$SINCE_ARG" | cut -d- -f2)"
    START_MONTH=$((10#$START_MONTH))
    echo "--> Finding monthly commits since $SINCE_ARG"
else
    START_YEAR=$((CURRENT_YEAR - 5))
    START_MONTH=$CURRENT_MONTH
    echo "--> Finding monthly commits for the last 5 years"
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
echo "--> Analyzing $TOTAL revisions (this may take a few minutes)"

# ── 3. Run linguist + git ls-tree on each revision ───────────────────────
for i in $(seq 0 $((TOTAL - 1))); do
    month="${MONTHS[$i]}"
    sha="${COMMITS[$i]}"
    echo "  [$((i + 1))/$TOTAL] $month"
    github-linguist --rev "$sha" --breakdown --json > "$DATA_DIR/${month}.linguist.json" 2>&1
    git ls-tree -r -l "$sha" > "$DATA_DIR/${month}.lstree.txt"
done

# ── 4. Generate the HTML chart using Python ───────────────────────────────
echo "--> Generating chart"

python3 << 'PYEOF'
import json
import os
from datetime import date

data_dir = os.environ.get("DATA_DIR", "_linguist_tmp/data")
output_file = os.environ.get("OUTPUT_FILE", "language-trends.html")

# Collect all months sorted
months = sorted(set(
    f.replace(".linguist.json", "")
    for f in os.listdir(data_dir)
    if f.endswith(".linguist.json")
))

LANGUAGES = ["Swift", "Objective-C", "C", "C++", "Objective-C++", "Shell"]
SCOPES = {
    "Sources/": "Sources",
    "Tests/": "Tests",
}

# For each month, compute per-scope language percentages AND absolute sizes
# Strategy: linguist gives us file->language mapping, git ls-tree gives us file->size
pct_results = {}   # {scope: {lang: [pct_per_month]}}
abs_results = {}   # {scope: {lang: [kb_per_month]}}
for scope_key in list(SCOPES.keys()) + ["overall"]:
    pct_results[scope_key] = {lang: [] for lang in LANGUAGES}
    abs_results[scope_key] = {lang: [] for lang in LANGUAGES}

for month in months:
    # Parse linguist breakdown: {lang: {size, percentage, files: [path, ...]}}
    with open(os.path.join(data_dir, f"{month}.linguist.json")) as f:
        linguist = json.load(f)

    # Build file -> language mapping from linguist
    file_to_lang = {}
    for lang, info in linguist.items():
        for fpath in info.get("files", []):
            file_to_lang[fpath] = lang

    # Parse git ls-tree for file sizes
    file_sizes = {}
    with open(os.path.join(data_dir, f"{month}.lstree.txt")) as f:
        for line in f:
            # Format: <mode> <type> <hash> <size>\t<path>
            parts = line.strip().split(None, 4)
            if len(parts) == 5 and parts[1] == "blob":
                try:
                    size = int(parts[3])
                except ValueError:
                    continue
                file_sizes[parts[4]] = size

    # Compute per-scope totals
    for scope_prefix, scope_name in SCOPES.items():
        lang_sizes = {lang: 0 for lang in LANGUAGES}
        total_size = 0
        for fpath, size in file_sizes.items():
            if not fpath.startswith(scope_prefix):
                continue
            lang = file_to_lang.get(fpath)
            if lang and lang in lang_sizes:
                lang_sizes[lang] += size
                total_size += size
            elif lang:
                total_size += size

        for lang in LANGUAGES:
            pct = (lang_sizes[lang] / total_size * 100) if total_size > 0 else 0
            pct_results[scope_prefix][lang].append(round(pct, 2))
            abs_results[scope_prefix][lang].append(round(lang_sizes[lang] / 1024, 1))

    # Overall (from linguist directly)
    for lang in LANGUAGES:
        if lang in linguist:
            pct_results["overall"][lang].append(float(linguist[lang]["percentage"]))
            abs_results["overall"][lang].append(round(linguist[lang]["size"] / 1024, 1))
        else:
            pct_results["overall"][lang].append(0)
            abs_results["overall"][lang].append(0)

# ── Generate HTML ─────────────────────────────────────────────────────────

COLORS = {
    "Swift": "#F05138",
    "Objective-C": "#438EFF",
    "C": "#555555",
    "C++": "#F34B7D",
    "Objective-C++": "#6866FB",
    "Shell": "#89E051",
}

def make_datasets(data_dict, scope_key):
    datasets = []
    for lang in LANGUAGES:
        is_major = lang in ("Swift", "Objective-C", "C")
        datasets.append({
            "label": lang,
            "data": data_dict[scope_key][lang],
            "borderColor": COLORS[lang],
            "borderWidth": 2.5 if is_major else 1.5,
            "pointRadius": 0,
            "pointHoverRadius": 5 if is_major else 4,
            "tension": 0.3,
            "fill": False,
        })
    return json.dumps(datasets)

labels_json = json.dumps(months)
today = date.today().isoformat()

charts_html = ""
charts_js = ""

chart_configs = [
    ("overall", "Overall (Entire Repository)"),
    ("Sources/", "Sources/ (Production Code)"),
    ("Tests/", "Tests/ (Test Code)"),
]

# Helper to generate crossover detection JS
def crossover_js(var_name, ds_var):
    return f"""
let {var_name} = -1;
for (let i = 0; i < {ds_var}[0].data.length; i++) {{
  if ({ds_var}[0].data[i] > {ds_var}[1].data[i]) {{ {var_name} = i; break; }}
}}"""

# Helper to generate crossover annotation plugin JS
def crossover_plugin_js(var_name):
    return f"""{{
    afterDraw: function(chart) {{
      if ({var_name} < 0) return;
      const meta = chart.getDatasetMeta(0);
      if (!meta.data[{var_name}]) return;
      const x = meta.data[{var_name}].x;
      const ctx = chart.ctx;
      const yAxis = chart.scales.y;
      ctx.save();
      ctx.beginPath();
      ctx.setLineDash([4, 4]);
      ctx.strokeStyle = '#8b949e';
      ctx.lineWidth = 1;
      ctx.moveTo(x, yAxis.top);
      ctx.lineTo(x, yAxis.bottom);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#656d76';
      ctx.font = '11px -apple-system, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Swift overtakes Obj-C', x, yAxis.top - 6);
      ctx.fillText(labels[{var_name}], x, yAxis.top + 10);
      ctx.restore();
    }}
  }}"""

for scope_key, title in chart_configs:
    safe = scope_key.replace("/", "") or "overall"

    # ── Percentage chart ──
    pct_id = f"pct_{safe}"
    pct_ds = f"ds_pct_{safe}"
    pct_xo = f"xo_pct_{safe}"

    charts_html += f"""
<h2>{title} — Percentage</h2>
<p class="chart-note">Share of each language relative to the total code in this scope.</p>
<div class="chart-wrapper">
  <canvas id="{pct_id}"></canvas>
</div>
"""
    charts_js += f"""
const {pct_ds} = {make_datasets(pct_results, scope_key)};
{crossover_js(pct_xo, pct_ds)}
new Chart(document.getElementById('{pct_id}').getContext('2d'), {{
  type: 'line',
  data: {{ labels: labels, datasets: {pct_ds} }},
  options: {{
    responsive: true,
    maintainAspectRatio: false,
    interaction: {{ mode: 'index', intersect: false }},
    plugins: {{
      legend: {{ position: 'top', labels: {{ usePointStyle: true, pointStyle: 'circle', padding: 16, font: {{ size: 12 }} }} }},
      tooltip: {{ callbacks: {{ label: function(ctx) {{ return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%'; }} }} }}
    }},
    scales: {{
      x: {{ grid: {{ display: false }}, ticks: {{ maxRotation: 45, callback: function(v, i) {{ const l = labels[i]; return (l && l.endsWith('-01')) ? l.substring(0, 4) : ''; }}, font: {{ size: 11 }} }} }},
      y: {{ min: 0, ticks: {{ callback: function(v) {{ return v + '%'; }}, stepSize: 10, font: {{ size: 11 }} }}, grid: {{ color: '#e1e4e8' }} }}
    }}
  }},
  plugins: [{crossover_plugin_js(pct_xo)}]
}});
"""

    # ── Absolute size chart ──
    abs_id = f"abs_{safe}"
    abs_ds = f"ds_abs_{safe}"
    abs_xo = f"xo_abs_{safe}"

    charts_html += f"""
<h2>{title} — Absolute Size</h2>
<p class="chart-note">Total bytes of code per language (KB). Shows actual growth independent of other languages.</p>
<div class="chart-wrapper">
  <canvas id="{abs_id}"></canvas>
</div>
"""
    charts_js += f"""
const {abs_ds} = {make_datasets(abs_results, scope_key)};
{crossover_js(abs_xo, abs_ds)}
new Chart(document.getElementById('{abs_id}').getContext('2d'), {{
  type: 'line',
  data: {{ labels: labels, datasets: {abs_ds} }},
  options: {{
    responsive: true,
    maintainAspectRatio: false,
    interaction: {{ mode: 'index', intersect: false }},
    plugins: {{
      legend: {{ position: 'top', labels: {{ usePointStyle: true, pointStyle: 'circle', padding: 16, font: {{ size: 12 }} }} }},
      tooltip: {{ callbacks: {{ label: function(ctx) {{ return ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(0) + ' KB'; }} }} }}
    }},
    scales: {{
      x: {{ grid: {{ display: false }}, ticks: {{ maxRotation: 45, callback: function(v, i) {{ const l = labels[i]; return (l && l.endsWith('-01')) ? l.substring(0, 4) : ''; }}, font: {{ size: 11 }} }} }},
      y: {{ min: 0, ticks: {{ callback: function(v) {{ return (v >= 1024) ? (v / 1024).toFixed(1) + ' MB' : v + ' KB'; }}, font: {{ size: 11 }} }}, grid: {{ color: '#e1e4e8' }} }}
    }}
  }},
  plugins: [{crossover_plugin_js(abs_xo)}]
}});
"""

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sentry Cocoa SDK — Language Trends</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<style>
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #fff;
    margin: 0;
    padding: 24px 32px;
    color: #24292f;
  }}
  h1 {{ font-size: 22px; font-weight: 600; margin-bottom: 4px; }}
  h2 {{ font-size: 17px; font-weight: 600; margin-top: 36px; margin-bottom: 4px; color: #24292f; }}
  .subtitle {{ font-size: 13px; color: #656d76; margin-bottom: 8px; }}
  .chart-note {{ font-size: 12px; color: #656d76; margin: 0 0 8px 0; }}
  .chart-wrapper {{ position: relative; width: 100%; max-width: 1100px; height: 420px; margin-bottom: 12px; }}
</style>
</head>
<body>

<h1>Sentry Cocoa SDK — Language Breakdown Over Time</h1>
<p class="subtitle">Monthly data points, computed with <a href="https://github.com/github-linguist/linguist">github-linguist</a> (same tool GitHub uses). Generated on {today}.</p>
<p class="subtitle"><strong>Percentage charts</strong> show each language's share relative to total code — a language can shrink in percentage while growing in absolute size if other languages grow faster.
<strong>Absolute size charts</strong> show the actual amount of code (in KB) per language, revealing true growth and removal trends.</p>
{charts_html}
<script>
const labels = {labels_json};
{charts_js}
</script>
</body>
</html>"""

with open(output_file, "w") as f:
    f.write(html)

print(f"  Written to {output_file}")
PYEOF

echo "--> Chart written to $OUTPUT_FILE"

# ── 5. Open in browser ───────────────────────────────────────────────────
if [ "${CI:-}" != "true" ]; then
    if command -v open &> /dev/null; then
        open "$OUTPUT_FILE"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$OUTPUT_FILE"
    fi
fi

echo "--> Done! Temporary gem directory cleaned up."
