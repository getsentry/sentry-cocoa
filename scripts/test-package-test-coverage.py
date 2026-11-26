#!/usr/bin/env python3
"""Exercise package coverage preparation through the test wrapper, without Xcode."""

import copy
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


class XcodebuildWrapperTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="coverage wrapper ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.derived = self.root / "DerivedData"
        self.products = self.derived / "Build/Products"
        self.products.mkdir(parents=True)
        self.metadata = {
            "TestPlan": {"Name": "SentrySPM_Base"},
            "TestConfigurations": [{"TestTargets": [{
                "TestBundlePath": "__TESTROOT__/TestCI/SentryTests.xctest",
                "ClangProfileDataDirectoryPath": "__DERIVEDDATA__/Build/ProfileData",
                "OnlyTestIdentifiers": ["SelectedTest"],
                "SkipTestIdentifiers": ["SomeTest/testSkipped"],
                "EnvironmentVariables": {"UNCHANGED": "yes"},
            }]}],
            "CodeCoverageBuildableInfos": [{
                "ProductPaths": ["__TESTROOT__/TestCI/SentryTests.xctest/SentryTests"],
                "SourceFilesCommonPathPrefix": str(self.root / "package") + "/",
                "SourceFiles": ["Tests/test.m"], "IncludeInReport": True,
            }, {
                "ProductPaths": ["__TESTROOT__/TestCI/Recording.o"],
                "SourceFiles": ["external.c"],
            }],
        }
        self.original = self.products / "SentrySPM_SentrySPM_Base_macosx27.2-arm64.xctestrun"
        self.original.write_bytes(plistlib.dumps(self.metadata))
        self.calls = self.root / "calls.jsonl"
        self.calls.write_text("")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "xcodebuild": f"#!{sys.executable}\nimport json, os, sys\n"
                          "with open(os.environ['CALLS'], 'a') as log:\n"
                          "    log.write(json.dumps(sys.argv) + '\\n')\n",
            "xcbeautify": "#!/bin/sh\n/bin/cat\n",
        }.items():
            path = self.bin / name
            path.write_text(body)
            path.chmod(0o755)
        self.wrapper = Path(__file__).with_name("sentry-xcodebuild.sh").resolve()

    def run_wrapper(self, command="test-without-building", scheme="SentrySPM",
                    plan="SentrySPM_Base", v10="0", check=True):
        return subprocess.run([
            "bash", str(self.wrapper), "--platform", "macOS", "--command", command,
            "--scheme", scheme, "--workspace", str(self.root / "package"),
            "--configuration", "TestCI", "--derived-data", str(self.derived),
            "--test-plan", plan, "--only-testing", "SentryTests/SentryIdTests",
            "--result-bundle", str(self.root / "results.xcresult"),
            "--", "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO",
        ], cwd=self.root, env={**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                              "CALLS": str(self.calls), "FOR_AGENTS": "true", "SDK_V10": v10},
            check=check, capture_output=True, text=True)

    def commands(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def selected_metadata(self):
        command = self.commands()[-1]
        return Path(command[command.index("-xctestrun") + 1])

    def test_changes_only_test_bundle_source_filters_and_preserves_original(self):
        self.run_wrapper()
        output = self.selected_metadata()
        expected = copy.deepcopy(self.metadata)
        expected["CodeCoverageBuildableInfos"][0].pop("SourceFiles")
        self.assertEqual(plistlib.loads(output.read_bytes()), expected)
        self.assertEqual(plistlib.loads(self.original.read_bytes()), self.metadata)
        self.assertEqual(output.parent, self.original.parent)
        first_output = output.read_bytes()
        self.run_wrapper()
        self.assertEqual(self.selected_metadata().read_bytes(), first_output)

    def test_split_execution_selects_exact_plan_including_v10_default(self):
        for plan in ["SentrySPM_Base_v10", "SentrySPM_Flaky"]:
            metadata = copy.deepcopy(self.metadata)
            metadata["TestPlan"]["Name"] = plan
            (self.products / f"SentrySPM_{plan}_macosx27.2-arm64.xctestrun").write_bytes(plistlib.dumps(metadata))
        for index, (plan, v10) in enumerate([("SentrySPM_Base", "0"), ("SentrySPM_Flaky", "0"), ("", "1")], 1):
            with self.subTest(plan=plan):
                self.run_wrapper(plan=plan, v10=v10)
                self.assertEqual(len(self.commands()), index)
                data = plistlib.loads(self.selected_metadata().read_bytes())
                self.assertEqual(data["TestPlan"]["Name"], plan or "SentrySPM_Base_v10")

    def test_missing_ambiguous_and_wrong_configuration_fail_before_launch(self):
        result = self.run_wrapper(plan="Missing", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)
        extra = self.products / "SentrySPM_SentrySPM_Base_macosx27.1-arm64.xctestrun"
        extra.write_bytes(self.original.read_bytes())
        result = self.run_wrapper(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)
        extra.unlink()
        self.metadata["TestConfigurations"][0]["TestTargets"][0]["TestBundlePath"] = "__TESTROOT__/Test/SentryTests.xctest"
        self.original.write_bytes(plistlib.dumps(self.metadata))
        result = self.run_wrapper(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("configuration", result.stderr)
        self.assertEqual(self.commands(), [])

    def test_disabled_coverage_is_unchanged(self):
        self.metadata.pop("CodeCoverageBuildableInfos")
        self.original.write_bytes(plistlib.dumps(self.metadata))
        self.run_wrapper()
        self.assertEqual(plistlib.loads(self.selected_metadata().read_bytes()), self.metadata)

    def test_package_build_exports_all_plans_and_preserves_launch_arguments(self):
        self.run_wrapper("test")
        calls = self.commands()
        self.assertEqual(len(calls), 2)
        build, run = calls
        self.assertIn("build-for-testing", build)
        self.assertNotIn("-testPlan", build)
        for option in ["-workspace", "-scheme", "-configuration", "-testPlan", "-xcconfig"]:
            self.assertNotIn(option, run)
        for option, value in {
            "-derivedDataPath": str(self.derived),
            "-resultBundlePath": str(self.root / "results.xcresult"),
            "-destination": f"platform=macOS,arch={os.uname().machine}", "-parallel-testing-enabled": "NO",
        }.items():
            self.assertEqual(run[run.index(option) + 1], value)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", run)
        self.assertIn("-only-testing:SentryTests/SentryIdTests", run)
        self.assertIn("test-without-building", run)
        self.assertTrue(self.selected_metadata().is_file())

    def test_project_route_is_unchanged(self):
        self.run_wrapper("test", scheme="Sentry", plan="Sentry_Base")
        calls = self.commands()
        self.assertEqual(len(calls), 2)
        for call in calls:
            self.assertIn("-workspace", call)
            self.assertIn("-scheme", call)
            self.assertIn("-testPlan", call)
            self.assertNotIn("-xctestrun", call)


if __name__ == "__main__":
    unittest.main()
