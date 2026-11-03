"""Test standalone SwiftPM API generation with fake Xcode tools."""

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
    log.write(json.dumps({"tool": tool, "args": args, "sdkV10": os.environ.get("SDK_V10")}) + "\n")
def argument(name):
    return args[args.index(name) + 1]
if tool == "xcodebuild":
    if args == ["-version"]:
        print("Xcode " + os.environ.get("XCODE_VERSION", "16.4") + "\nBuild version fixture")
        sys.exit(0)
    source = Path(argument("-workspace"))
    for name in ("Sentry.xcodeproj", "Sentry.xcworkspace", ".swiftpm"):
        assert not (source / name).exists()
    for manifest in source.glob("Package*.swift"):
        assert "BEGIN:BINARY" not in manifest.read_text()
    assert (source / "untracked.txt").read_text() == "included"
    assert not (source / "ignored.txt").exists()
    assert not (source / "deleted.txt").exists()
    if "-list" in args:
        sys.exit(0)
    if os.environ.get("FAIL_BUILD"):
        print("fixture build failed", file=sys.stderr)
        sys.exit(65)
    derived = Path(argument("-derivedDataPath"))
    module = derived / ("Build/Products/" + argument("-configuration") + "-iphoneos/SentrySwift.swiftmodule")
    module.mkdir(parents=True)
    for suffix in ("swiftmodule", "swiftinterface", "private.swiftinterface", "package.swiftinterface"):
        (module / ("fixture." + suffix)).write_text("fixture")
    module_map = derived / "Build/Intermediates.noindex/GeneratedModuleMaps-iphoneos/SentryHeaders.modulemap"
    module_map.parent.mkdir(parents=True)
    module_map.write_text("module SentryHeaders { export * }")
    settings = next(arg.split("=", 1)[1] for arg in args if arg.startswith("SWIFT_INCLUDE_PATHS="))
    paths = shlex.split(settings)
    assert paths[0] == "$(inherited)"
    assert (Path(paths[1]) / "module.modulemap").resolve() == module_map.resolve()
    assert Path(paths[2]) == source / "Sources/Sentry/Public"
    assert "SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO" not in args
elif "swift-api-digester" in args:
    if os.environ.get("FAIL_EXTRACT"):
        print("fixture extraction failed", file=sys.stderr)
        sys.exit(70)
    if "-I" in args:
        api = Path(argument("-I"))
        assert not list(api.rglob("*.private.swiftinterface"))
        assert not list(api.rglob("*.package.swiftinterface"))
        assert not any(path.is_file() for path in api.rglob("*.swiftmodule"))
    children = [{"kind": "TypeDecl", "name": name} for name in ("SentrySDK", "Options")]
    children.append({"kind": "Function", "name": "example", "children": [
        {"kind": "TypeNominal", "printedName": name} for name in ("()", "Swift.String", "Swift.Int")]})
    if os.environ.get("EMPTY_API"):
        children = []
    Path(argument("-o")).write_text(json.dumps({"ABIRoot": {
        "kind": "Root", "json_format_version": 8, "children": children}}))
else:
    raise AssertionError(args)
'''


class GenerationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="spm api generation ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "checkout"
        scripts = self.repo / "scripts"
        scripts.mkdir(parents=True)
        for name in ("generate-spm-api.sh", "extract-swift-api.sh", "prepare-package.sh", "ci-utils.sh"):
            shutil.copy2(SCRIPTS / name, scripts / name)
        for name in ("Package.swift", "Package@swift-6.1.swift", "Package@swift-6.2.swift"):
            (self.repo / name).write_text(
                "// source targets\n// BEGIN:BINARY_PRODUCTS\nbinary product\n// END:BINARY_PRODUCTS\n"
                "// BEGIN:BINARY_TARGETS\nbinary target\n// END:BINARY_TARGETS\n")
        for name in ("Sentry.xcodeproj/project.pbxproj", "Sentry.xcworkspace/contents.xcworkspacedata",
                     ".swiftpm/xcode/fixture", "Sources/Sentry/Public/fixture.h", "deleted.txt"):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        (self.repo / ".gitignore").write_text("ignored.txt\n")
        subprocess.run(["git", "init", "--quiet", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        (self.repo / "untracked.txt").write_text("included")
        (self.repo / "ignored.txt").write_text("excluded")
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

    def run_script(self, *arguments, **environment):
        return subprocess.run(
            ["bash", str(self.repo / "scripts/generate-spm-api.sh"), "--output-dir", str(self.output), *arguments],
            cwd=self.repo, env={**self.env, **environment}, capture_output=True, text=True)

    def calls(self, tool, argument):
        return [call for call in map(json.loads, self.log.read_text().splitlines())
                if call["tool"] == tool and argument in call["args"]]

    def assert_succeeded(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_v9_generation_without_project_formats_snapshot(self):
        shutil.rmtree(self.repo / "Sentry.xcodeproj")
        shutil.rmtree(self.repo / "Sentry.xcworkspace")
        self.assert_succeeded(self.run_script(SDK_V10="1"))
        build, = self.calls("xcodebuild", "build")
        self.assertEqual(build["sdkV10"], "0")
        args = build["args"]
        self.assertEqual(args[args.index("-scheme") + 1], "SentrySPM")
        self.assertEqual(args[args.index("-sdk") + 1], "iphoneos")
        extraction, = self.calls("xcrun", "swift-api-digester")
        args = extraction["args"]
        self.assertEqual([args[i + 1] for i, arg in enumerate(args) if arg == "-module"],
                         ["SentrySwift", "SentryHeaders"])
        self.assertEqual(args[args.index("-target") + 1], "arm64-apple-ios10.0")
        nodes = json.loads((self.output / "sdk_api.json").read_text())["ABIRoot"]["children"]
        parameters = [node["printedName"] for node in next(n for n in nodes if n["name"] == "example")["children"]]
        self.assertEqual(parameters, ["()", "Swift.Int", "Swift.String"])
        self.assertEqual(list(self.output.glob("*.json")), [self.output / "sdk_api.json"])
        self.assertEqual(list(self.output.glob("work.*")), [])
        self.assertFalse((self.repo / "sdk_api.json").exists())

    def test_v10_uses_v10_scheme_configuration_and_headers(self):
        self.assert_succeeded(self.run_script("--generation", "v10"))
        build, = self.calls("xcodebuild", "build")
        self.assertEqual(build["sdkV10"], "1")
        args = build["args"]
        self.assertEqual(args[args.index("-scheme") + 1], "Sentry")
        self.assertEqual(args[args.index("-configuration") + 1], "ReleaseV10")
        extraction, = self.calls("xcrun", "swift-api-digester")
        self.assertTrue(any(arg.endswith("/SentryV10Configuration/include") for arg in extraction["args"]))
        self.assertFalse(any("SentryCrashV9Headers" in arg for arg in extraction["args"]))
        self.assertTrue((self.output / "sdk_api_v10.json").is_file())
        self.assertEqual(list(self.output.glob("*.json")), [self.output / "sdk_api_v10.json"])

    def test_build_and_extraction_failures_propagate_and_keep_logs(self):
        for flag, status, log in (("FAIL_BUILD", 65, "build"), ("FAIL_EXTRACT", 70, "extract")):
            with self.subTest(flag=flag):
                self.output = self.root / flag
                result = self.run_script(**{flag: "1"})
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertTrue((self.output / f"logs/{log}.log").is_file())
                self.assertEqual(list(self.output.glob("work.*")), [])

    def test_empty_extraction_is_an_error(self):
        result = self.run_script(EMPTY_API="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing expected SDK declarations", result.stdout)

    def test_keep_builds_preserves_sources_and_original_interfaces(self):
        before = (self.repo / "Package.swift").read_bytes()
        self.assert_succeeded(self.run_script("--keep-builds"))
        work, = self.output.glob("work.*")
        self.assertTrue(list((work / "build").rglob("*.private.swiftinterface")))
        self.assertTrue(any(path.is_file() for path in (work / "build").rglob("*.swiftmodule")))
        self.assertFalse(list((work / "api").rglob("*.private.swiftinterface")))
        self.assertEqual((self.repo / "Package.swift").read_bytes(), before)
        self.assertTrue((self.repo / "Sentry.xcodeproj").is_dir())

    def test_invalid_arguments_fail_before_running_tools(self):
        for arguments in (("--generation", "invalid"), ("--generation",), ("--build-system", "both")):
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_script(*arguments).returncode, 2)
                self.assertFalse(self.output.exists())
                self.assertFalse(self.log.exists())

    def test_rejects_existing_output_without_modifying_it(self):
        self.output.mkdir()
        marker = self.output / "preserve.txt"
        marker.write_text("preserve")
        self.assertEqual(self.run_script().returncode, 2)
        self.assertEqual(marker.read_text(), "preserve")
        self.assertFalse(self.log.exists())

    def test_rejects_output_inside_checkout_including_symlink(self):
        link = self.root / "checkout-link"
        link.symlink_to(self.repo, target_is_directory=True)
        for parent in (self.repo, link):
            with self.subTest(parent=parent):
                self.output = parent / "output"
                self.assertEqual(self.run_script().returncode, 2)
                self.assertFalse(self.output.exists())
                self.assertFalse(self.log.exists())

    def test_requires_xcode_16_for_complete_objc_extraction(self):
        self.assertNotEqual(self.run_script(XCODE_VERSION="27.1").returncode, 0)
        self.assertEqual(self.calls("xcodebuild", "build"), [])
        self.assertFalse(self.output.exists())

    def test_extractor_rejects_empty_module_before_running_tools(self):
        result = subprocess.run(
            ["bash", str(self.repo / "scripts/extract-swift-api.sh"), "--module", "",
             "--output", str(self.root / "invalid.json"), "--include-path", str(self.root)],
            env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_existing_framework_extractor_defaults_are_unchanged(self):
        framework = self.root / "Sentry.xcframework/ios-arm64/Sentry.framework"
        framework.mkdir(parents=True)
        private = framework / "fixture.private.swiftinterface"
        private.write_text("private")
        result = subprocess.run(
            ["bash", str(self.repo / "scripts/extract-swift-api.sh"), "--module", "Sentry",
             "--output", str(self.root / "legacy.json"), "--framework-path", str(framework.parent)],
            env=self.env, capture_output=True, text=True)
        self.assert_succeeded(result)
        extraction, = self.calls("xcrun", "swift-api-digester")
        args = extraction["args"]
        self.assertEqual(args, ["--sdk", "iphoneos", "swift-api-digester", "-dump-sdk",
                               "-o", str(self.root / "legacy.json"), "-abort-on-module-fail",
                               "-avoid-tool-args", "-avoid-location", "-module", "Sentry",
                               "-target", "arm64-apple-ios10.0", "-iframework", str(framework.parent)])
        self.assertFalse(private.exists())


if __name__ == "__main__":
    unittest.main()
