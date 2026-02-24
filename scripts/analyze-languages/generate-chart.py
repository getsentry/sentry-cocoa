#!/usr/bin/env python3
"""
Generates an interactive HTML chart from github-linguist and git ls-tree data.

Usage:
    python3 generate-chart.py --data-dir <path> --output-file <path>

The data directory should contain pairs of files for each month:
    YYYY-MM.linguist.json  (output of github-linguist --breakdown --json)
    YYYY-MM.lstree.txt     (output of git ls-tree -r -l)
"""

import argparse
import json
import os
from datetime import date


LANGUAGES = ["Swift", "Objective-C", "C", "C++", "Objective-C++", "Shell"]
SCOPES = {
    "Sources/": "Sources",
    "Tests/": "Tests",
}
COLORS = {
    "Swift": "#F05138",
    "Objective-C": "#438EFF",
    "C": "#555555",
    "C++": "#F34B7D",
    "Objective-C++": "#6866FB",
    "Shell": "#89E051",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Generate language trends HTML chart")
    parser.add_argument("--data-dir", required=True, help="Directory containing linguist JSON and lstree files")
    parser.add_argument("--output-file", required=True, help="Path for the output HTML file")
    return parser.parse_args()


def collect_months(data_dir):
    return sorted(set(
        f.replace(".linguist.json", "")
        for f in os.listdir(data_dir)
        if f.endswith(".linguist.json")
    ))


def compute_results(data_dir, months):
    pct_results = {}  # {scope: {lang: [pct_per_month]}}
    abs_results = {}  # {scope: {lang: [kb_per_month]}}
    for scope_key in list(SCOPES.keys()) + ["overall"]:
        pct_results[scope_key] = {lang: [] for lang in LANGUAGES}
        abs_results[scope_key] = {lang: [] for lang in LANGUAGES}

    for month in months:
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
        for scope_prefix in SCOPES:
            lang_sizes = {lang: 0 for lang in LANGUAGES}
            total_size = 0
            for fpath, size in file_sizes.items():
                if not fpath.startswith(scope_prefix):
                    continue
                total_size += size
                lang = file_to_lang.get(fpath)
                if lang and lang in lang_sizes:
                    lang_sizes[lang] += size

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

    return pct_results, abs_results


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


def crossover_js(var_name, ds_var):
    return f"""
let {var_name} = -1;
for (let i = 1; i < {ds_var}[0].data.length; i++) {{
  if ({ds_var}[0].data[i] > {ds_var}[1].data[i] && {ds_var}[0].data[i - 1] <= {ds_var}[1].data[i - 1]) {{ {var_name} = i; break; }}
}}"""


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


def generate_html(months, pct_results, abs_results):
    labels_json = json.dumps(months)
    today = date.today().isoformat()

    charts_html = ""
    charts_js = ""

    chart_configs = [
        ("overall", "Overall (Entire Repository)"),
        ("Sources/", "Sources/ (Production Code)"),
        ("Tests/", "Tests/ (Test Code)"),
    ]

    for scope_key, title in chart_configs:
        safe = scope_key.replace("/", "") or "overall"

        # Percentage chart
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

        # Absolute size chart
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

    # The HTML template uses Python f-string interpolation for chart data,
    # labels, and dynamic content — it can't function as a standalone file.
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sentry Cocoa SDK — Language Trends</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js" integrity="sha384-vsrfeLOOY6KuIYKDlmVH5UiBmgIdB1oEf7p01YgWHuqmOHfZr374+odEv96n9tNC" crossorigin="anonymous"></script>
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


def main():
    args = parse_args()
    months = collect_months(args.data_dir)
    pct_results, abs_results = compute_results(args.data_dir, months)
    html = generate_html(months, pct_results, abs_results)

    with open(args.output_file, "w") as f:
        f.write(html)

    print(f"  Written to {args.output_file}")


if __name__ == "__main__":
    main()
