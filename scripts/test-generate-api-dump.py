"""Exercise API generation orchestration with fake Xcode tools, without SDK builds."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
FAKE_TOOL = r'''import json
import os
from pathlib import Path
import shlex
import sys

args = sys.argv[1:]
tool = Path(sys.argv[0]).name
with open(os.environ["TOOL_LOG"], "a") as log:
    log.write(json.dumps({"tool": tool, "args": args}) + "\n")

def argument(name):
    return args[args.index(name) + 1]

if tool == "xcodebuild":
    if args == ["-version"]:
        print("Xcode 16.4\nBuild version fixture")
        sys.exit(0)
    if "-workspace" in args:
        source = Path(argument("-workspace"))
        assert not (source / "Sentry.xcodeproj").exists()
        assert not (source / "Sentry.xcworkspace").exists()
        assert not (source / ".swiftpm").exists()
        for manifest in source.glob("Package*.swift"):
            assert "BEGIN:BINARY" not in manifest.read_text()
    else:
        source = Path(argument("-project")).parent
    if "-list" in args:
        print("Schemes: SentrySPM")
        sys.exit(0)
    backend = "spm" if "-workspace" in args else "xcode"
    assert (source / "snapshot-marker.txt").read_text() == "original"
    assert not (source / "ignored.txt").exists()
    assert not (source / "deleted.txt").exists()
    if backend == "xcode" and os.environ.get("MUTATE_SOURCE"):
        Path(os.environ["MUTATE_SOURCE"]).write_text("changed during build")
    if os.environ.get("FAIL_BUILD") == backend:
        print("fixture build failed", file=sys.stderr)
        sys.exit(65)
    derived = Path(argument("-derivedDataPath"))
    products = derived / "Build/Products/Release-iphonesimulator"
    module = products / ("SentrySwift.swiftmodule" if backend == "spm" else "Sentry.framework")
    module.mkdir(parents=True)
    (module / "fixture.private.swiftinterface").write_text("private")
    (module / "fixture.swiftinterface").write_text("public")
    if backend == "spm":
        module_map = derived / "Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/SentryHeaders.modulemap"
        module_map.parent.mkdir(parents=True)
        module_map.write_text("module SentryHeaders { export * }")
        settings = next(arg.split("=", 1)[1] for arg in args if arg.startswith("SWIFT_INCLUDE_PATHS="))
        paths = shlex.split(settings)
        assert paths[0] == "$(inherited)"
        assert (Path(paths[1]) / "module.modulemap").resolve() == module_map.resolve()
        assert Path(paths[2]) == source / "Sources/Sentry/Public"
        assert "SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO" not in args
    print("BUILD SUCCEEDED")
elif args == ["--sdk", "iphonesimulator", "--show-sdk-path"]:
    print("/fixture/iPhoneSimulator.sdk")
elif args == ["swiftc", "--version"]:
    print("Swift 6.1.2")
else:
    assert "swift-api-digester" in args
    modules = Path(argument("-module-list-file"))
    backend = "spm" if modules.name.startswith("spm") else "xcode"
    if os.environ.get("FAIL_EXTRACT") == backend:
        print("fixture extraction failed", file=sys.stderr)
        sys.exit(70)
    header = "SentryHeaders" if backend == "spm" else "Sentry"
    children = [{"kind": "TypeDecl", "name": name, "printedName": name,
                 "moduleName": "SentrySwift" if backend == "spm" else "Sentry",
                 "children": []} for name in ("SentrySDK", "Options")]
    children.append({"kind": "Import", "name": header + ".Nested"})
    if backend == "xcode" and not os.environ.get("EQUAL_APIS"):
        children.append({"kind": "Var", "name": "XcodeOnly", "printedName": "XcodeOnly"})
    if os.environ.get("EMPTY_API") == backend:
        children = []
    Path(argument("-o")).write_text(json.dumps({"ABIRoot": {
        "kind": "Root", "json_format_version": 8, "children": children}}))
'''


class GenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="api generation ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "checkout"
        scripts = self.repo / "scripts"
        scripts.mkdir(parents=True)
        for name in ("generate-api-dump.sh", "report-api-parity.sh", "compare-public-api.py",
                     "prepare-package.sh", "ci-utils.sh"):
            if (SCRIPTS / name).exists():
                shutil.copy2(SCRIPTS / name, scripts / name)
        for name in ("Package.swift", "Package@swift-6.1.swift", "Package@swift-6.2.swift"):
            (self.repo / name).write_text(
                "// source targets\n// BEGIN:BINARY_PRODUCTS\nbinary product\n"
                "// END:BINARY_PRODUCTS\n// BEGIN:BINARY_TARGETS\nbinary target\n"
                "// END:BINARY_TARGETS\n")
        for name in ("Sentry.xcodeproj/project.pbxproj", "Sentry.xcworkspace/contents.xcworkspacedata",
                     ".swiftpm/xcode/fixture", "Sources/Sentry/Public/fixture.h"):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        (self.repo / ".gitignore").write_text("ignored.txt\n")
        (self.repo / "deleted.txt").write_text("deleted after staging")
        subprocess.run(["git", "init", "--quiet", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false",
                        "commit", "--quiet", "-m", "fixture"], check=True)
        (self.repo / "snapshot-marker.txt").write_text("original")  # Untracked edits are included.
        (self.repo / "ignored.txt").write_text("do not copy")
        (self.repo / "deleted.txt").unlink()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("xcodebuild", "xcrun"):
            path = self.bin / name
            path.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            path.chmod(0o755)
        self.log = self.root / "tools.jsonl"
        self.output = self.root / "output"
        self.env = {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                    "TOOL_LOG": str(self.log), "GITHUB_ACTIONS": "false"}

    def run_script(self, script="generate-api-dump.sh", arguments=None, **environment):
        return subprocess.run(
            ["bash", str(self.repo / "scripts" / script),
             *(arguments if arguments is not None else ["--build-system", "spm"]),
             "--output-dir", str(self.output)],
            cwd=self.repo, env={**self.env, **environment}, capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def builds(self):
        return [call["args"] for call in self.calls()
                if call["tool"] == "xcodebuild" and "build" in call["args"]]

    def assert_succeeded(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_spm_generation_does_not_require_xcode_project(self):
        shutil.rmtree(self.repo / "Sentry.xcodeproj")
        shutil.rmtree(self.repo / "Sentry.xcworkspace")
        result = self.run_script()
        self.assert_succeeded(result)
        self.assertEqual(len(self.builds()), 1)
        self.assertIn("-workspace", self.builds()[0])
        self.assertFalse(any("-project" in call["args"] for call in self.calls()))
        self.assertTrue((self.output / "spm-public.json").is_file())
        self.assertFalse((self.output / "xcode-public.json").exists())
        self.assertFalse((self.output / "report").exists())
        self.assertEqual(json.loads((self.output / "context.json").read_text())["buildSystem"], "spm")
        self.assertIn("SentryHeaders.Nested", (self.output / "spm-modules.txt").read_text())
        self.assertEqual(list(self.output.glob("work.*")), [])

    def test_xcode_generation_does_not_build_package(self):
        result = self.run_script(arguments=["--build-system", "xcode"])
        self.assert_succeeded(result)
        self.assertEqual(len(self.builds()), 1)
        self.assertIn("-project", self.builds()[0])
        self.assertFalse(any("-workspace" in call["args"] for call in self.calls()))
        self.assertTrue((self.output / "xcode-public.json").is_file())
        self.assertFalse((self.output / "spm-public.json").exists())

    def test_both_builds_use_one_snapshot_and_do_not_compare(self):
        result = self.run_script(arguments=["--build-system", "both"],
                                 MUTATE_SOURCE=str(self.repo / "snapshot-marker.txt"))
        self.assert_succeeded(result)
        self.assertEqual(len(self.builds()), 2)
        self.assertTrue((self.output / "xcode-public.json").is_file())
        self.assertTrue((self.output / "spm-public.json").is_file())
        self.assertFalse((self.output / "report").exists())

    def test_parity_differences_remain_warnings(self):
        result = self.run_script("report-api-parity.sh", arguments=[])
        self.assert_succeeded(result)
        self.assertIn("[warning]", result.stdout)
        summary = json.loads((self.output / "report/summary.json").read_text())
        self.assertFalse(summary["equal"])
        self.assertEqual(summary["changes"][0]["path"], "XcodeOnly")

    def test_equal_parity_succeeds_without_warning(self):
        result = self.run_script("report-api-parity.sh", arguments=[], EQUAL_APIS="1")
        self.assert_succeeded(result)
        self.assertNotIn("[warning]", result.stdout)
        self.assertTrue(json.loads((self.output / "report/summary.json").read_text())["equal"])

    def test_build_failure_is_not_downgraded_to_warning(self):
        result = self.run_script("report-api-parity.sh", arguments=[], FAIL_BUILD="spm")
        self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
        self.assertTrue((self.output / "logs/build-spm.log").is_file())
        self.assertFalse((self.output / "report/summary.md").exists())
        self.assertEqual(list(self.output.glob("work.*")), [])

    def test_extraction_failure_is_not_downgraded_to_warning(self):
        result = self.run_script("report-api-parity.sh", arguments=[], FAIL_EXTRACT="spm")
        self.assertEqual(result.returncode, 70, result.stdout + result.stderr)
        self.assertTrue((self.output / "logs/extract-spm-1.log").is_file())
        self.assertFalse((self.output / "report/summary.md").exists())

    def test_empty_extraction_fails_before_comparison(self):
        result = self.run_script("report-api-parity.sh", arguments=[], EMPTY_API="spm")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.output / "report/summary.md").exists())

    def test_keep_builds_preserves_original_private_interfaces(self):
        result = self.run_script(arguments=["--build-system", "spm", "--keep-builds"])
        self.assert_succeeded(result)
        work, = self.output.glob("work.*")
        self.assertTrue(list((work / "spm").rglob("*.private.swiftinterface")))
        self.assertFalse(list((work / "api").rglob("*.private.swiftinterface")))
        self.assertEqual((self.repo / "snapshot-marker.txt").read_text(), "original")

    def test_rejects_invalid_build_system_before_running_tools(self):
        result = self.run_script(arguments=["--build-system", "invalid"])
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.log.exists())

    def test_rejects_output_inside_checkout(self):
        self.output = self.repo / "output"
        result = self.run_script()
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.log.exists())

    def test_rejects_existing_output_without_modifying_it(self):
        self.output.mkdir()
        marker = self.output / "preserve.txt"
        marker.write_text("preserve")
        result = self.run_script()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(marker.read_text(), "preserve")
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
