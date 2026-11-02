#!/usr/bin/env python3
"""Compare Sentry source API dumps locally, without modifying either input.

Use raw swift-api-digester -dump-sdk output from the same toolchain/platform.
Include transitively exported header modules: Sentry plus its header submodules
for Xcode, SentrySwift plus SentryHeaders for SwiftPM. The caller must ensure
these extraction settings match; stripped digester metadata cannot prove that.
Do not mix raw dumps with snapshots that recursively sort parameter arrays.

Module identities are deliberately normalized; this is NOT an ABI comparison.
Exit status: 0 = equal source API, 1 = differences, 2 = invalid input/arguments.
"""

import argparse
from collections import defaultdict
import difflib
from html import escape
import json
from pathlib import Path
import re
import sys

MODULE_NAMES = re.compile(r"\b(?:SentrySwift|SentryHeaders)\b")
IDENTITY_FIELDS = {"usr", "mangledName", "superclassUsr"}
UNORDERED_FIELDS = {"declAttributes", "typeAttributes", "conformances", "accessors"}


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False)


def normalize(value):
    if isinstance(value, str):
        return MODULE_NAMES.sub("Sentry", value)
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if not isinstance(value, dict):
        return value

    result = {key: normalize(item) for key, item in value.items()
              if key not in IDENTITY_FIELDS}
    for key in UNORDERED_FIELDS:
        if key in result:
            result[key] = sorted(result[key], key=canonical)
    if result.get("kind") in {"Root", "TypeDecl"} and "children" in result:
        result["children"] = sorted(result["children"], key=canonical)
    # Function children encode return/parameter order. Never sort those.
    return result


def load_api(path):
    root = json.loads(path.read_text())["ABIRoot"]
    if (not isinstance(root, dict) or root.get("kind") != "Root"
            or not isinstance(root.get("children"), list)):
        raise ValueError(f"{path}: expected an ABIRoot with declaration children")
    declarations = []
    for node in root["children"]:
        if node["kind"] == "Import":
            continue
        if (node["kind"] == "TypeAlias" and node.get("moduleName") == "__ObjC"
                and node.get("name", "").startswith("__")):
            continue  # Reserved compiler builtin aliases, not SDK declarations.
        declarations.append(normalize(node))
    if not declarations:
        raise ValueError(f"{path}: no API declarations; extraction may be incomplete")
    return root["json_format_version"], sorted(declarations, key=canonical)


def group_declarations(declarations):
    groups = defaultdict(list)
    for node in declarations:
        groups[(node["kind"], node["printedName"])].append(node)
    # Preserve overloads: a dict containing just one node per name loses APIs.
    return {key: sorted(nodes, key=canonical) for key, nodes in groups.items()}


def compare_declarations(baseline, candidate, parent=""):
    old, new = group_declarations(baseline), group_declarations(candidate)
    changes = []
    for key in sorted(old.keys() | new.keys()):
        kind, name = key
        path = f"{parent}.{name}" if parent else name
        if key not in new:
            changes.append({"change": "removed", "path": path, "kind": kind})
        elif key not in old:
            changes.append({"change": "added", "path": path, "kind": kind})
        elif old[key] != new[key]:
            if kind == "TypeDecl" and len(old[key]) == len(new[key]) == 1:
                left, right = old[key][0], new[key][0]
                if ({k: v for k, v in left.items() if k != "children"}
                        != {k: v for k, v in right.items() if k != "children"}):
                    changes.append({"change": "changed", "path": path,
                                    "kind": kind, "detail": "type attributes/conformances"})
                changes.extend(compare_declarations(
                    left.get("children", []), right.get("children", []), path))
            else:
                changes.append({"change": "changed", "path": path, "kind": kind,
                                "detail": "signature, attributes, accessors, or overloads"})
    return changes


def markdown_report(changes):
    lines = [
        "## Xcode / SwiftPM API parity", "",
        "This report is informational. API differences do not fail the parity job.", "",
        "V9 Release, arm64 iOS Simulator. Module names and ABI symbol identities are "
        "normalized; this compares source API, not binary compatibility or behavior.", "",
    ]
    if not changes:
        lines.append("No source API differences detected.")
    else:
        labels = {"removed": "Missing from SwiftPM", "added": "Only in SwiftPM", "changed": "Changed"}
        lines += [f"**{len(changes)} API difference(s)**", "",
                  "| Difference | Declaration |", "| --- | --- |"]
        # Keep the Actions summary bounded; the artifact always contains every change.
        for change in changes[:100]:
            name = escape(change["path"]).replace("|", "&#124;").replace("`", "&#96;")
            name = name.replace("\n", " ").replace("\r", " ")
            lines.append(f"| {labels[change['change']]} | `{name}` |")
        if len(changes) > 100:
            lines += ["", "Showing the first 100 differences; see the artifact for the full list."]
    lines += ["", "The artifact contains the raw and normalized APIs, full diff, and build logs.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-b", "--baseline", type=Path, required=True, help="Xcode API JSON")
    parser.add_argument("-c", "--candidate", type=Path, required=True, help="SwiftPM API JSON")
    parser.add_argument("-o", "--output-dir", type=Path, required=True,
                        help="Directory for normalized JSON, diff, and summary (overwritten)")
    args = parser.parse_args()
    output_names = ("baseline-normalized.json", "candidate-normalized.json",
                    "api.diff", "summary.json", "summary.md")
    try:
        inputs = {args.baseline.resolve(), args.candidate.resolve()}
        if any((args.output_dir / name).resolve() in inputs for name in output_names):
            raise ValueError("output files must not overwrite the input dumps")
        baseline_version, baseline = load_api(args.baseline)
        candidate_version, candidate = load_api(args.candidate)
        if baseline_version != candidate_version:
            raise ValueError("digester format versions differ; use the same toolchain")
        changes = compare_declarations(baseline, candidate)
        args.output_dir.mkdir(parents=True, exist_ok=True)
        texts = [json.dumps(nodes, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
                 for nodes in (baseline, candidate)]
        for name, content in zip(output_names[:2], texts):
            (args.output_dir / name).write_text(content)
        (args.output_dir / "api.diff").write_text("".join(difflib.unified_diff(
            texts[0].splitlines(keepends=True), texts[1].splitlines(keepends=True),
            fromfile="Xcode (normalized)", tofile="SwiftPM (normalized)")))
        summary = {"baseline": str(args.baseline.resolve()),
                   "candidate": str(args.candidate.resolve()),
                   "moduleAliases": {"SentrySwift": "Sentry", "SentryHeaders": "Sentry"},
                   "baselineTopLevel": len(baseline), "candidateTopLevel": len(candidate),
                   "equal": baseline == candidate, "changes": changes}
        (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        (args.output_dir / "summary.md").write_text(markdown_report(changes))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.error(str(error))

    print("Source API comparison (module identities normalized; not an ABI check)")
    for change in changes:
        print(f"{change['change'].upper():7} {change['path']}")
    print(f"\n{'MATCH' if baseline == candidate else 'DIFFERENT'}; "
          f"{len(changes)} difference(s). Reports: {args.output_dir.resolve()}")
    return 0 if baseline == candidate else 1


if __name__ == "__main__":
    sys.exit(main())
