#!/usr/bin/env python3
"""Patch Swift package traits in XcodeGen-generated .xcodeproj files.

Finds every project.pbxproj under Samples/ and adds or removes a named
Swift package trait on every XCLocalSwiftPackageReference entry.
"""

import argparse
import os
import re
import sys


def log_info(msg: str) -> None:
    print(msg)


def log_warning(msg: str) -> None:
    print(f"::warning::{msg}")


def log_error(msg: str) -> None:
    print(f"::error::{msg}", file=sys.stderr)


def begin_group(title: str) -> None:
    print(f"::group::{title}")


def end_group() -> None:
    print("::endgroup::")


def patch_block(block: str, trait: str, mode: str) -> str:
    """Add or remove a trait from a single XCLocalSwiftPackageReference block."""
    trait_line = f"\t\t\t\t{trait},\n"
    traits_block = f"\t\t\ttraits = (\n{trait_line}\t\t\t);\n"

    if mode == "add":
        if "\t\t\ttraits = (\n" in block:
            if trait_line in block:
                return block  # already present
            return block.replace("\t\t\ttraits = (\n", f"\t\t\ttraits = (\n{trait_line}")
        else:
            return block.replace("\t\t};\n", f"{traits_block}\t\t}};\n")
    else:  # remove
        block = block.replace(trait_line, "")
        block = re.sub(r"\t\t\ttraits = \(\n\t\t\t\);\n", "", block)
        return block


def patch_pbxproj(path: str, trait: str, mode: str) -> bool:
    """Patch a single project.pbxproj. Returns True if the file changed."""
    with open(path) as f:
        content = f.read()

    pattern = re.compile(
        r"\t\t\w+ /\* XCLocalSwiftPackageReference \"[^\"]*\" \*/ = \{[^}]+\};\n",
        re.DOTALL,
    )

    new_content = pattern.sub(lambda m: patch_block(m.group(0), trait, mode), content)

    if new_content != content:
        with open(path, "w") as f:
            f.write(new_content)
        return True
    return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("-t", "--trait", required=True, help="Package trait name to add or remove")
    parser.add_argument(
        "-m", "--mode", required=True, choices=["add", "remove"], help="Whether to add or remove the trait"
    )
    args = parser.parse_args()

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    samples_dir = os.path.join(repo_root, "Samples")

    pbxproj_files = []
    for dirpath, dirnames, filenames in os.walk(samples_dir):
        dirnames[:] = [d for d in dirnames if d != ".build"]
        for filename in filenames:
            if filename == "project.pbxproj":
                pbxproj_files.append(os.path.join(dirpath, filename))

    if not pbxproj_files:
        log_warning("No project.pbxproj files found under Samples/ — run 'make xcode-ci' first")
        sys.exit(0)

    for pbxproj in sorted(pbxproj_files):
        project = os.path.basename(os.path.dirname(os.path.dirname(pbxproj)))
        begin_group(f"{args.mode} trait '{args.trait}' in {project}")
        changed = patch_pbxproj(pbxproj, args.trait, args.mode)
        log_info("  Updated" if changed else "  No change needed")
        end_group()

    action = "added" if args.mode == "add" else "removed"
    log_info(f"Done: trait '{args.trait}' {action} in {len(pbxproj_files)} project(s)")


if __name__ == "__main__":
    main()
