"""Test the combined API update workflow with fake Xcode tools and real extractors."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
SNAPSHOTS = {
    "sdk_api.json", "sdk_api_sentryswiftui.json", "sdk_api_objc.json",
    "sdk_api_objccompat.json", "sdk_api_objc.diff.json", "sdk_api_v10.json",
    "sdk_api_objc_v10.json", "sdk_api_objccompat_v10.json", "sdk_api_objc_v10.diff.json",
    "sdk_api_spm.json", "sdk_api_objc_spm.json", "sdk_api_objccompat_spm.json", "sdk_api_objc_spm.diff.json",
    "sdk_api_v10_spm.json", "sdk_api_objc_v10_spm.json", "sdk_api_objccompat_v10_spm.json",
    "sdk_api_objc_v10_spm.diff.json",
}
FAKE_TOOL = r'''import json
import os
from pathlib import Path
import shutil
import sys

args = sys.argv[1:]
tool = Path(sys.argv[0]).name
with open(os.environ["TOOL_LOG"], "a") as log:
    log.write(json.dumps({"tool": tool, "args": args, "sdkV10": os.environ.get("SDK_V10"),
                         "developerDir": os.environ.get("DEVELOPER_DIR")}) + "\n")
def argument(name):
    return args[args.index(name) + 1]
def write_header(root):
    root.mkdir(parents=True, exist_ok=True)
    if os.environ.get("MISSING_COMPAT_HEADER"):
        return
    header = root / "SentryObjCCompat.build/Objects-normal/arm64/SentryObjCCompat-Swift.h"
    header.parent.mkdir(parents=True, exist_ok=True)
    header.write_text("fixture " + os.environ.get("SDK_V10", "0"))
if tool == "find":
    if args[0] == "/Applications":
        if not os.environ.get("NO_XCODE_16"):
            print("/Applications/Xcode-16.fixture.app")
    else:
        os.execv("/usr/bin/find", ["find", *args])
elif tool == "xcodebuild":
    if args == ["-version"]:
        version = "16.4" if os.environ.get("DEVELOPER_DIR", "").endswith("Xcode-16.fixture.app/Contents/Developer") else os.environ.get("XCODE_VERSION", "16.4")
        print("Xcode " + version + "\nBuild version fixture")
        sys.exit(0)
    if os.environ.get("FAIL_BUILD"):
        sys.exit(65)
    # Compatibility extraction already builds SwiftPM; reuse its snapshot later.
    objroot = next((arg.split("=", 1)[1] for arg in args if arg.startswith("OBJROOT=")), None)
    assert objroot, "Source SDK builds must use the existing archiver"
    write_header(Path(objroot))
elif tool == "build-static-library-sentryobjc.sh":
    if os.environ.get("FAIL_SPM_BUILD"):
        sys.exit(65)
    for name in ("Sentry.xcodeproj", "Sentry.xcworkspace", ".swiftpm"):
        assert Path(name).exists()
    for manifest in Path.cwd().glob("Package*.swift"):
        assert "BEGIN:BINARY" in manifest.read_text(), "Do not rewrite package manifests"
    scheme = argument("--scheme")
    assert scheme == ("Sentry" if os.environ.get("SDK_V10") == "1" else "SentrySPM")
    assert argument("--architecture-target") == "SentrySwift"
    assert argument("--sdk") == "iphoneos"
    root = Path(argument("--output-dir"))
    library = root / ("lib/" + scheme + "/iphoneos/lib" + scheme + "-Debug.a")
    library.parent.mkdir(parents=True, exist_ok=True)
    library.write_text("fixture")
    module = root / ("archive/" + scheme + "/iphoneos.xcarchive/Products/Swift/SentrySwift.swiftmodule")
    module.mkdir(parents=True, exist_ok=True)
    (module / "arm64-apple-ios.swiftinterface").write_text("fixture")
elif tool == "build-dynamic-framework-sentryobjc.sh":
    if os.environ.get("FAIL_SPM_PACKAGE"):
        sys.exit(66)
    assert Path(argument("--static-lib")).is_file()
    assert (Path(argument("--swift-archive")) / "Products/Swift/SentrySwift.swiftmodule").is_dir()
    assert argument("--framework-name") == "SentrySwift"
    module = Path(argument("--output-dir")) / "framework/SentrySwift/iphoneos/SentrySwift.framework/Modules/SentrySwift.swiftmodule"
    module.mkdir(parents=True, exist_ok=True)
    for suffix in ("swiftinterface", "private.swiftinterface"):
        (module / ("arm64-apple-ios." + suffix)).write_text("fixture")
elif tool in ("build-xcframework-slice.sh", "assemble-xcframework.sh", "build-xcframework-v10.sh"):
    if os.environ.get("FAIL_BUILD"):
        sys.exit(65)
    if tool == "assemble-xcframework.sh" and "--framework-template" in args:
        if os.environ.get("FAIL_SPM_ASSEMBLE"):
            sys.exit(67)
        source = Path(argument("--framework-template").replace("SDK_NAME", "iphoneos"))
        destination = Path(argument("--output")) / "ios-arm64/SentrySwift.framework"
        shutil.copytree(source, destination, dirs_exist_ok=True)
        sys.exit(0)
    if tool == "assemble-xcframework.sh":
        name = argument("--scheme") + (argument("--suffix") if "--suffix" in args else "")
    elif tool == "build-xcframework-v10.sh":
        name = "SentryV10-Dynamic"
    else:
        sys.exit(0)
    path = Path(name + ".xcframework/ios-arm64_arm64e/fixture.private.swiftinterface")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("private")
elif "swift-api-digester" in args:
    spm = argument("-module") == "SentrySwift"
    if os.environ.get("FAIL_EXTRACT") or (os.environ.get("FAIL_SPM_EXTRACT") and spm):
        sys.exit(70)
    if spm:
        framework = Path(argument("-iframework")) / "SentrySwift.framework"
        assert framework.is_dir()
        assert not list(framework.rglob("*.private.swiftinterface"))
        assert not list(framework.rglob("*.swiftmodule")) or all(p.is_dir() for p in framework.rglob("*.swiftmodule"))
        assert "-I" not in args, "Extraction must use only the packaged framework"
        assert "-use-interface-for-module" not in args
    children = [{"kind": "TypeDecl", "name": name, "moduleName": argument("-module")}
                for name in ("SentrySDK", "Options")]
    children.append({"kind": "Function", "name": "example", "children": [
        {"kind": "TypeNominal", "printedName": name} for name in ("()", "Swift.String", "Swift.Int")]})
    Path(argument("-o")).write_text(json.dumps({"ABIRoot": {
        "kind": "Root", "json_format_version": 8, "children": children}}))
elif "--show-sdk-path" in args:
    print("/fixture/iphoneos")
elif "clang" in args:
    if os.environ.get("FAIL_OBJC"):
        sys.exit(71)
    if args[-1].endswith("-Swift.h") and os.environ.get("FAIL_COMPAT"):
        sys.exit(72)
    header = Path(args[-1])
    assert header.is_file()
    is_v10 = "-DSDK_V10=1" in args if header.name == "SentryObjC.h" else header.read_text() == "fixture 1"
    print(json.dumps({"inner": [{"kind": "ObjCInterfaceDecl", "name": "SentryObjCSDK", "inner": [
        {"kind": "ObjCMethodDecl", "name": "v10" if is_v10 else "v9", "returnType": {"qualType": "void"}}
    ]}]}))
else:
    raise AssertionError(args)
'''


class UpdateApiTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="update api ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "checkout"
        scripts = self.repo / "scripts"
        scripts.mkdir(parents=True)
        for name in ("update-api.sh", "extract-swift-api.sh", "extract-objc-api.sh",
                     "extract-objc-compat-api.sh", "generate-objc-compat-api-diff.sh", "ci-utils.sh"):
            shutil.copy2(SCRIPTS / name, scripts / name)
        for name in ("build-xcframework-slice.sh", "assemble-xcframework.sh", "build-xcframework-v10.sh",
                     "build-static-library-sentryobjc.sh", "build-dynamic-framework-sentryobjc.sh"):
            self.fake_tool(scripts / name)
        for name in ("Package.swift", "Package@swift-6.1.swift", "Package@swift-6.2.swift"):
            (self.repo / name).write_text(
                "// source targets\n// BEGIN:BINARY_PRODUCTS\nbinary product\n// END:BINARY_PRODUCTS\n"
                "// BEGIN:BINARY_TARGETS\nbinary target\n// END:BINARY_TARGETS\n")
        for name in ("Sentry.xcodeproj/project.pbxproj", "Sentry.xcworkspace/contents.xcworkspacedata",
                     ".swiftpm/xcode/fixture", "Sources/Sentry/Public/fixture.h",
                     "Sources/SentryObjC/Public/SentryObjC.h"):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("xcodebuild", "xcrun", "find"):
            self.fake_tool(self.bin / name)
        self.log = self.root / "tools.jsonl"
        temporary = self.root / "tmp"
        temporary.mkdir()
        self.env = {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}", "TMPDIR": str(temporary),
                    "TOOL_LOG": str(self.log), "GITHUB_ACTIONS": "false", "DEVELOPER_DIR": "/fixture/current"}

    def fake_tool(self, path):
        path.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
        path.chmod(0o755)

    def run_script(self, **environment):
        return subprocess.run(
            ["bash", str(self.repo / "scripts/update-api.sh")],
            cwd=self.repo, env={**self.env, **environment}, capture_output=True, text=True)

    def calls(self, tool, argument=None):
        return [call for call in map(json.loads, self.log.read_text().splitlines())
                if call["tool"] == tool and (argument is None or argument in call["args"])]

    def assert_succeeded(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_snapshots(self):
        self.assertEqual({path.name for path in self.repo.glob("*.json")}, SNAPSHOTS)
        for generation in ("", "_v10"):
            for build in ("", "_spm"):
                suffix = generation + build
                headers = json.loads((self.repo / f"sdk_api_objc{suffix}.json").read_text())
                compat = json.loads((self.repo / f"sdk_api_objccompat{suffix}.json").read_text())
                self.assertEqual(headers, compat)
                self.assertIn("v10" if generation else "v9", [node["name"] for node in headers])
                diff = json.loads((self.repo / f"sdk_api_objc{suffix}.diff.json").read_text())
                self.assertEqual(diff, {"only_in_headers": [], "only_in_compat": []})
                nodes = json.loads((self.repo / f"sdk_api{suffix}.json").read_text())["ABIRoot"]["children"]
                sdk = next(node for node in nodes if node["name"] == "SentrySDK")
                self.assertEqual(sdk["moduleName"], "SentrySwift" if build else "Sentry")
                parameters = [node["printedName"] for node in next(n for n in nodes if n["name"] == "example")["children"]]
                self.assertEqual(parameters, ["()", "Swift.Int", "Swift.String"])

    def test_default_runs_framework_and_spm_steps_without_overwriting_snapshots(self):
        before = (self.repo / "Package.swift").read_bytes()
        result = self.run_script(SDK_V10="1")
        self.assert_succeeded(result)
        self.assert_snapshots()
        self.assertEqual((self.repo / "Package.swift").read_bytes(), before)
        self.assertTrue((self.repo / "Sentry.xcodeproj").is_dir())
        self.assertTrue((self.repo / "Sentry.xcworkspace").is_dir())
        self.assertEqual(len(self.calls("build-xcframework-slice.sh")), 2)
        self.assertEqual(len(self.calls("build-xcframework-v10.sh")), 1)
        builds = self.calls("xcodebuild", "build")
        self.assertEqual(len(builds), 2)  # Compatibility snapshots are already built through SwiftPM.
        spm_builds = self.calls("build-static-library-sentryobjc.sh")
        self.assertEqual([call["sdkV10"] for call in spm_builds], ["0", "1"])
        for call in spm_builds:
            args = call["args"]
            self.assertEqual(args[args.index("--scheme") + 1], "Sentry" if call["sdkV10"] == "1" else "SentrySPM")
            self.assertEqual(args[args.index("--architecture-target") + 1], "SentrySwift")
            self.assertEqual(args[args.index("--configuration") + 1], "ReleaseV10" if call["sdkV10"] == "1" else "Release")
        self.assertEqual(len(self.calls("build-dynamic-framework-sentryobjc.sh")), 2)
        self.assertEqual(len(self.calls("assemble-xcframework.sh", "--framework-template")), 2)
        extractions = self.calls("xcrun", "swift-api-digester")
        self.assertEqual([[call["args"][i + 1] for i, arg in enumerate(call["args"]) if arg == "-module"]
                          for call in extractions], [["Sentry"], ["SentrySwiftUI"], ["Sentry"],
                                                    ["SentrySwift"], ["SentrySwift"]])
        self.assertTrue(all("-iframework" in call["args"] for call in extractions))
        self.assertTrue(all("-I" not in call["args"] for call in extractions))
        for call in extractions[3:]:
            args = call["args"]
            self.assertEqual(args[args.index("-target") + 1], "arm64-apple-ios10.0")
            self.assertTrue(args[args.index("-iframework") + 1].endswith("-SPM.xcframework/ios-arm64"))
        self.assertFalse((self.repo / "sdk_api_sentryswiftui_spm.json").exists())
        self.assertIn("Skipping SentrySwiftUI SwiftPM", result.stdout)
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_updates_existing_snapshots_in_checkout(self):
        for name in SNAPSHOTS:
            (self.repo / name).write_text("stale")
        self.assert_succeeded(self.run_script())
        self.assert_snapshots()

    def test_xcode_16_discovery_is_shared_by_all_steps(self):
        self.assert_succeeded(self.run_script(XCODE_VERSION="27.0"))
        builds = (self.calls("xcodebuild", "build") + self.calls("build-static-library-sentryobjc.sh")
                  + self.calls("build-dynamic-framework-sentryobjc.sh"))
        self.assertEqual(len(builds), 6)
        self.assertTrue(all(call["developerDir"] == "/Applications/Xcode-16.fixture.app/Contents/Developer"
                            for call in builds))

    def test_missing_xcode_16_fails_before_building(self):
        result = self.run_script(XCODE_VERSION="27.0", NO_XCODE_16="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("xcodebuild", "build"), [])

    def test_framework_failures_propagate(self):
        for flag, status in (("FAIL_BUILD", 65), ("FAIL_EXTRACT", 70), ("FAIL_OBJC", 71), ("FAIL_COMPAT", 72)):
            with self.subTest(flag=flag):
                result = self.run_script(**{flag: "1"})
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertFalse((self.repo / "sdk_api_spm.json").exists())
                self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_spm_failures_propagate_and_preserve_framework_snapshots(self):
        for flag, status in (("FAIL_SPM_BUILD", 65), ("FAIL_SPM_PACKAGE", 66),
                             ("FAIL_SPM_ASSEMBLE", 67), ("FAIL_SPM_EXTRACT", 70)):
            with self.subTest(flag=flag):
                result = self.run_script(**{flag: "1"})
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertTrue((self.repo / "sdk_api.json").exists())
                self.assertTrue((self.repo / "sdk_api_v10.json").exists())
                self.assertFalse((self.repo / "sdk_api_v10_spm.json").exists())
                self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_missing_compat_header_fails_before_packaging(self):
        result = self.run_script(MISSING_COMPAT_HEADER="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SentryObjCCompat-Swift.h not found", result.stdout)
        self.assertEqual(len(self.calls("xcodebuild", "build")), 1)
        self.assertEqual(self.calls("build-static-library-sentryobjc.sh"), [])
        self.assertFalse((self.repo / "sdk_api_objccompat_spm.json").exists())

    def test_make_target_uses_existing_no_argument_entrypoint(self):
        result = subprocess.run(["make", "-n", "generate-public-api"],
                                cwd=SCRIPTS.parent, capture_output=True, text=True)
        self.assert_succeeded(result)
        self.assertIn("./scripts/update-api.sh", result.stdout.splitlines())

    def test_extractor_rejects_empty_module_before_running_tools(self):
        result = subprocess.run(
            ["bash", str(self.repo / "scripts/extract-swift-api.sh"), "--module", "",
             "--output", str(self.root / "invalid.json"), "--include-path", str(self.root)],
            env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_compat_extractor_rejects_missing_supplied_header(self):
        result = subprocess.run(
            ["bash", str(self.repo / "scripts/extract-objc-compat-api.sh"), "--output", str(self.root / "compat.json"),
             "--swift-header", str(self.root / "missing.h")], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
