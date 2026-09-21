#!/usr/bin/env python3
"""Route package tests using the existing Xcode plans, or normalize enumerated tests."""

import argparse
from collections import Counter
import fnmatch
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PACKAGE_TARGETS = {
    "SentryTests": ("SentryTests", "SentryTestsObjC"),
    "SentryTestsV10": ("SentryTests", "SentryTestsObjC"),
    "SentryTestUtilsTests": ("SentryTestUtilsTests",),
    "SentryTestUtilsTestsV10": ("SentryTestUtilsTests",),
    "SentryObjCCompatTests": ("SentryObjCCompatTests",),
    "SentryObjCCompatTestsV10": ("SentryObjCCompatTests",),
}


def clang_classes(root=ROOT):
    classes = set()
    for path in (root / "Tests/SentryTests").rglob("*"):
        if path.suffix in (".m", ".mm"):
            classes.update(re.findall(r"@interface\s+(\w+)\s*:", path.read_text()))
    return classes


def plan_arguments(plan, classes):
    arguments = ["-parallel-testing-enabled", "NO"]
    if plan.get("defaultOptions", {}).get("testRepetitionMode") == "retryOnFailure":
        arguments += ["-retry-tests-on-failure", "-test-iterations", "3"]
    if plan.get("defaultOptions", {}).get("testTimeoutsEnabled"):
        arguments += ["-test-timeouts-enabled", "YES"]
    if plan.get("defaultOptions", {}).get("codeCoverage"):
        arguments += ["-enableCodeCoverage", "YES"]

    selected = []
    skipped = []
    for entry in plan["testTargets"]:
        targets = PACKAGE_TARGETS.get(entry["target"]["name"])
        if not targets:
            # Profiler/ObjC public API suites are not part of this migration.
            continue

        def mapped(identifier):
            target = targets[-1] if len(targets) == 2 and identifier.split("/")[0] in classes else targets[0]
            return f"{target}/{identifier.removesuffix('()')}"

        if "selectedTests" in entry:
            selected += [mapped(test) for test in entry["selectedTests"]]
        else:
            selected += list(targets)
        skipped += [mapped(test) for test in entry.get("skippedTests", [])]

    if not selected:
        raise ValueError("Plan selects no migrated package tests; refusing to run the whole suite")
    arguments += [f"-only-testing:{test}" for test in selected]
    arguments += [f"-skip-testing:{test}" for test in skipped]
    return arguments


def normalized_identifiers(enumeration):
    if enumeration.get("errors"):
        raise ValueError(f"Test enumeration failed: {enumeration['errors']}")
    identifiers = []

    def visit(node, target=None, test_class=None):
        kind = node.get("kind")
        if kind == "target":
            target = node["name"]
        elif kind == "class":
            test_class = node["name"].split(".")[-1]
        elif kind == "test" and target in ("SentryTests", "SentryTestsObjC", "SentryTestsV10"):
            if not test_class:
                raise ValueError(f"Missing class for XCTest: {node}")
            identifiers.append(f"SentryTests/{test_class}/{node['name'].removesuffix('()')}")
        for child in node.get("children", []):
            visit(child, target, test_class)

    for node in enumeration["values"]:
        visit(node)
    if len(set(identifiers)) != len(identifiers):
        raise ValueError("Duplicate normalized test identifiers")
    if not identifiers:
        raise ValueError("No SentryTests were discovered")
    return sorted(identifiers)


def audit_manifest(manifest, v10=False, root=ROOT):
    """Check source ownership against the synchronized Xcode group, including V10 exclusions."""
    test_root = root / "Tests/SentryTests"
    expected = {path for path in test_root.rglob("*") if path.suffix in (".swift", ".m", ".mm")}
    if v10:
        config = (root / "Tests/Configuration/SentryTestsV10.xcconfig").read_text()
        line = re.search(r"^EXCLUDED_SOURCE_FILE_NAMES = (.*)$", config, re.MULTILINE).group(1)
        patterns = [item.removeprefix("$(SRCROOT)/Tests/SentryTests/") for item in line.split() if item != "$(inherited)"]
        project = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(root / "Sentry.xcodeproj/project.pbxproj")
        ]))
        objects = project["objects"]
        target = next(key for key, value in objects.items() if value.get("isa") == "PBXNativeTarget" and value.get("name") == "SentryTestsV10")
        for value in objects.values():
            if value.get("isa") == "PBXFileSystemSynchronizedBuildFileExceptionSet" and value.get("target") == target:
                patterns += value.get("membershipExceptions", [])
        expected = {path for path in expected if not any(fnmatch.fnmatch(str(path.relative_to(test_root)), pattern) for pattern in patterns)}

    ownership = Counter()
    names = {"SentryTests", "SentryTestsObjC", "SentryTestsObjCHelpers", "SentryTestsSwiftHelpers"}
    targets = {target["name"]: target for target in manifest["targets"]}
    if not names <= targets.keys():
        raise ValueError(f"Missing package targets: {names - targets.keys()}")
    for name in names:
        target = targets[name]
        base = root / target["path"]
        exclusions = [base / excluded for excluded in target["exclude"]]
        for source in target["sources"]:
            path = base / source
            candidates = path.rglob("*") if path.is_dir() else [path]
            for candidate in candidates:
                if candidate.suffix not in (".swift", ".m", ".mm") or test_root not in candidate.parents:
                    continue
                if any(excluded == candidate or excluded in candidate.parents for excluded in exclusions):
                    continue
                ownership[candidate] += 1
                swift_target = name in ("SentryTests", "SentryTestsSwiftHelpers")
                if swift_target != (candidate.suffix == ".swift"):
                    raise ValueError(f"Mixed language source in {name}: {candidate}")
    missing = expected - ownership.keys()
    extra = ownership.keys() - expected
    duplicates = [path for path, count in ownership.items() if count != 1]
    if missing or extra or duplicates:
        raise ValueError(f"Source inventory mismatch: missing={sorted(missing)}, extra={sorted(extra)}, duplicates={duplicates}")

    def check_product(name, seen):
        if name in names or name.startswith("SentryTestUtils"):
            raise ValueError(f"Test support leaked into SDK product: {name}")
        if name in seen or name not in targets:
            return
        seen.add(name)
        for dependency in targets[name].get("dependencies", []):
            if "byName" in dependency:
                check_product(dependency["byName"][0], seen)
            elif "target" in dependency:
                check_product(dependency["target"][0], seen)
            elif "product" in dependency:
                check_product(dependency["product"][0], seen)
    for product in manifest["products"]:
        for name in product["targets"]:
            check_product(name, set())
    return f"Audited {len(expected)} SentryTests sources; each has one package owner and no SDK product includes test support."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--plan", type=Path, help="Xcode .xctestplan; print one xcodebuild argument per line")
    action.add_argument("--normalize", type=Path, help="JSON from xcodebuild -enumerate-tests; print normalized identifiers")
    action.add_argument("--audit-manifest", type=Path, help="JSON from swift package dump-package; verify Xcode source parity and product isolation")
    parser.add_argument("--v10", action="store_true", help="Use Xcode's V10 source exclusions when auditing")
    args = parser.parse_args()
    if args.audit_manifest:
        print(audit_manifest(json.loads(args.audit_manifest.read_text()), args.v10))
        return
    if args.plan:
        output = plan_arguments(json.loads(args.plan.read_text()), clang_classes())
    else:
        output = normalized_identifiers(json.loads(args.normalize.read_text()))
    print("\n".join(output))


if __name__ == "__main__":
    main()
