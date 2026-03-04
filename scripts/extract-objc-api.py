#!/usr/bin/env python3
"""
Extract public API declarations from SentryObjC headers for stability tracking.

Outputs a sorted JSON array of declaration signatures. Used by update-api.sh
to generate sdk_objc_api.json. Changes to the output indicate API changes.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def normalize_whitespace(s: str) -> str:
    """Collapse whitespace to single spaces."""
    return " ".join(s.split())


def extract_declarations(header_path: Path, content: str) -> list[str]:
    """Extract public API declarations from header content."""
    decls: list[str] = []
    lines = content.split("\n")

    # Track multi-line declarations
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip empty, comments, imports, preprocessor
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            i += 1
            continue
        if stripped.startswith("/*") or stripped.startswith("*") or stripped.startswith("*/"):
            i += 1
            continue
        if "import" in stripped and ("<" in stripped or '"' in stripped):
            i += 1
            continue
        if stripped.startswith("NS_ASSUME_NONNULL") or stripped.startswith("@class "):
            i += 1
            continue

        # @interface Name : Super
        if re.match(r"@interface\s+\w+", stripped):
            buf = [stripped]
            j = i + 1
            while j < len(lines) and not lines[j].strip().startswith("@end"):
                buf.append(lines[j].strip())
                j += 1
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j + 1
            continue

        # @protocol Name
        if re.match(r"@protocol\s+\w+", stripped):
            buf = [stripped]
            j = i + 1
            while j < len(lines) and not lines[j].strip().startswith("@end"):
                buf.append(lines[j].strip())
                j += 1
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j + 1
            continue

        # @property (...)
        if stripped.startswith("@property"):
            buf = [stripped]
            j = i + 1
            while j < len(lines) and not lines[j].strip().endswith(";"):
                buf.append(lines[j].strip())
                j += 1
            if j < len(lines):
                buf.append(lines[j].strip())
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j + 1
            continue

        # - (ret)method or + (ret)method
        if re.match(r"^[+-]\s*\(", stripped):
            buf = [stripped]
            j = i + 1
            while j < len(lines) and not lines[j].strip().endswith(";"):
                buf.append(lines[j].strip())
                j += 1
            if j < len(lines):
                buf.append(lines[j].strip())
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j + 1
            continue

        # typedef ... ;
        if stripped.startswith("typedef "):
            buf = [stripped]
            j = i + 1
            while j < len(lines) and ";" not in stripped:
                buf.append(lines[j].strip())
                stripped = lines[j].strip()
                j += 1
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j
            continue

        # NS_ENUM(...) { ... }
        if "NS_ENUM" in stripped or "NS_OPTIONS" in stripped:
            buf = [stripped]
            j = i + 1
            brace_count = stripped.count("{") - stripped.count("}")
            while j < len(lines) and brace_count > 0:
                buf.append(lines[j].strip())
                brace_count += lines[j].count("{") - lines[j].count("}")
                j += 1
            decls.append(normalize_whitespace(" ".join(buf)))
            i = j
            continue

        # NS_STRING_ENUM / NS_SWIFT_NAME - single line
        if "NS_STRING_ENUM" in stripped or "NS_SWIFT_NAME" in stripped:
            decls.append(normalize_whitespace(stripped))
            i += 1
            continue

        i += 1

    return decls


def main() -> None:
    headers_dir = Path(__file__).resolve().parent.parent / "Sources" / "SentryObjC" / "Public"
    if not headers_dir.is_dir():
        print("error: SentryObjC Public headers not found", file=sys.stderr)
        sys.exit(1)

    all_decls: list[str] = []
    for h in sorted(headers_dir.glob("*.h")):
        if h.name == "SentryObjC.h":
            continue  # Umbrella header, no declarations
        content = h.read_text(encoding="utf-8", errors="replace")
        decls = extract_declarations(h, content)
        for d in decls:
            all_decls.append(f"{h.name}: {d}")

    all_decls = sorted(set(all_decls))
    print(json.dumps(all_decls, indent=2))


if __name__ == "__main__":
    main()
