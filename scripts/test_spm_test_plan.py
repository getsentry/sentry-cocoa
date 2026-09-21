#!/usr/bin/env python3
"""Regression tests for package routing and inventory normalization (no dependencies)."""

import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("spm_test_plan", Path(__file__).with_name("spm-test-plan.py"))
ROUTING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ROUTING)


class PackagePlanTests(unittest.TestCase):
    def test_all_existing_plans_preserve_each_selected_and_skipped_identifier(self):
        classes = ROUTING.clang_classes()
        for name in ("Sentry_Base", "Sentry_Flaky", "Sentry_TestServer", "SentryV10_Base", "SentryV10_TestServer"):
            with self.subTest(plan=name):
                plan = json.loads((ROUTING.ROOT / f"Plans/{name}.xctestplan").read_text())
                arguments = ROUTING.plan_arguments(plan, classes)
                for entry in plan["testTargets"]:
                    targets = ROUTING.PACKAGE_TARGETS.get(entry["target"]["name"])
                    if not targets:
                        continue
                    for key, flag in (("selectedTests", "only"), ("skippedTests", "skip")):
                        for identifier in entry.get(key, []):
                            target = targets[-1] if len(targets) == 2 and identifier.split("/")[0] in classes else targets[0]
                            self.assertIn(f"-{flag}-testing:{target}/{identifier.removesuffix('()')}", arguments)
                self.assertIn("-parallel-testing-enabled", arguments)

    def test_flaky_plan_keeps_three_attempts_and_does_not_select_whole_targets(self):
        plan = json.loads((ROUTING.ROOT / "Plans/Sentry_Flaky.xctestplan").read_text())
        arguments = ROUTING.plan_arguments(plan, ROUTING.clang_classes())
        self.assertIn("-retry-tests-on-failure", arguments)
        self.assertEqual(arguments[arguments.index("-test-iterations") + 1], "3")
        self.assertNotIn("-only-testing:SentryTests", arguments)
        self.assertNotIn("-only-testing:SentryTestsObjC", arguments)

    def test_empty_selection_fails_closed(self):
        with self.assertRaises(ValueError):
            ROUTING.plan_arguments({"testTargets": []}, set())

    def test_normalization_maps_both_package_targets_and_v10_to_project(self):
        def inventory(target, name):
            return {"values": [{"kind": "target", "name": target, "children": [
                {"kind": "class", "name": "SentryTests.ExampleTests", "children": [
                    {"kind": "test", "name": name}
                ]}
            ]}]}

        expected = ["SentryTests/ExampleTests/testExample"]
        for target, name in (("SentryTests", "testExample()"), ("SentryTestsObjC", "testExample"), ("SentryTestsV10", "testExample()")):
            self.assertEqual(ROUTING.normalized_identifiers(inventory(target, name)), expected)

    def test_all_manifests_share_the_source_inventory(self):
        inventories = []
        for name in ("Package.swift", "Package@swift-6.1.swift", "Package@swift-6.2.swift"):
            manifest = (ROUTING.ROOT / name).read_text()
            start = manifest.index("let sentryTestClangFiles =")
            end = manifest.index("targets += [", start)
            inventories.append(manifest[start:end])
        self.assertEqual(inventories[0], inventories[1])
        self.assertEqual(inventories[0], inventories[2])

    def test_source_audit_rejects_missing_duplicate_and_published_test_support(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sources = root / "Tests/SentryTests"
            sources.mkdir(parents=True)
            (sources / "Example.swift").write_text("class Example {}")
            manifest = {"products": [], "targets": [
                {"name": name, "path": "Tests", "exclude": [], "sources": ["SentryTests/Example.swift"] if name == "SentryTests" else []}
                for name in ("SentryTests", "SentryTestsObjC", "SentryTestsObjCHelpers", "SentryTestsSwiftHelpers")
            ]}
            self.assertIn("Audited 1", ROUTING.audit_manifest(manifest, root=root))
            missing = copy.deepcopy(manifest)
            missing["targets"][0]["sources"] = []
            duplicate = copy.deepcopy(manifest)
            duplicate["targets"][3]["sources"] = ["SentryTests/Example.swift"]
            published = copy.deepcopy(manifest)
            published["products"] = [{"targets": ["SentryTestsSwiftHelpers"]}]
            for invalid in (missing, duplicate, published):
                with self.assertRaises(ValueError):
                    ROUTING.audit_manifest(invalid, root=root)

    def test_empty_or_failed_enumeration_is_not_a_matching_inventory(self):
        for data in ({"values": []}, {"errors": ["Bundle did not load"], "values": []}):
            with self.assertRaises(ValueError):
                ROUTING.normalized_identifiers(data)


if __name__ == "__main__":
    unittest.main()
