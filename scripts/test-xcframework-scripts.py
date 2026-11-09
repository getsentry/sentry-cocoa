"""Regression tests for XCFramework assembly, compression and builder arguments."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

SCRIPTS = Path(__file__).resolve().parent


class XCFrameworkScriptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="xcframework scripts ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.calls = self.root / "xcodebuild.json"
        self.env = {**os.environ, "PATH": f"{self.tools}:{os.environ['PATH']}",
                    "GITHUB_ACTIONS": "false", "XCODEBUILD_CALLS": str(self.calls)}
        self.tool("xcodebuild", '''#!/usr/bin/env python3
import json, os, pathlib, sys
pathlib.Path(os.environ["XCODEBUILD_CALLS"]).write_text(json.dumps(sys.argv[1:]))
if sys.argv[1] != "-create-xcframework":
    sys.exit("Unexpected build: argument validation should happen first")
''')

    def tool(self, name, content):
        path = self.tools / name
        path.write_text(content)
        path.chmod(0o755)

    def run_script(self, script, *args):
        return subprocess.run([str(SCRIPTS / script), *map(str, args)], cwd=self.root,
                              env=self.env, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=30)

    def assemble(self, *args):
        return self.run_script("assemble-xcframework.sh", "--sdks", "macosx",
                               "--output", "Fixture.xcframework", *args)

    def test_required_dsym_is_attached_for_each_framework_input(self):
        for mode, framework, dsym, extra in [
            ("--framework-template", "slices/macosx/Fixture.framework",
             "slices/macosx/Fixture.framework.dSYM", []),
            ("--archive-template", "slices/macosx.xcarchive/Products/Library/Frameworks/Fixture.framework",
             "slices/macosx.xcarchive/dSYMs/Fixture.framework.dSYM", ["--scheme", "Fixture"]),
        ]:
            with self.subTest(mode=mode):
                (self.root / framework).mkdir(parents=True)
                (self.root / dsym).mkdir(parents=True)
                template = ("slices/SDK_NAME/Fixture.framework" if mode == "--framework-template"
                            else "slices/SDK_NAME.xcarchive")
                result = self.assemble(mode, template, *extra, "--require-debug-symbols")
                self.assertEqual(result.returncode, 0, result.stdout)
                args = json.loads(self.calls.read_text())
                self.assertEqual(args[args.index("-debug-symbols") + 1], str(self.root / dsym))

    def test_missing_required_dsym_preserves_existing_output(self):
        (self.root / "Fixture.framework").mkdir()
        output = self.root / "Fixture.xcframework"
        output.mkdir()
        marker = output / "existing"
        marker.touch()
        result = self.assemble("--framework-template", "Fixture.framework", "--require-debug-symbols")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing required dSYM:", result.stdout)
        self.assertTrue(marker.exists())
        self.assertFalse(self.calls.exists())

    def test_sentryobjc_dynamic_caller_requires_dsym_before_replacing_output(self):
        (self.root / "Fixture.framework").mkdir()
        output = self.root / "Fixture.xcframework"
        output.mkdir()
        marker = output / "existing"
        marker.touch()
        args = ("--sdks", "macosx", "--framework-path-template", "Fixture.framework",
                "--output-name", "Fixture")
        result = self.run_script("assemble-xcframework-sentryobjc.sh", *args)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing required dSYM:", result.stdout)
        self.assertTrue(marker.exists())
        self.assertFalse(self.calls.exists())
        (self.root / "Fixture.framework.dSYM").mkdir()
        result = self.run_script("assemble-xcframework-sentryobjc.sh", *args)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("-debug-symbols", json.loads(self.calls.read_text()))

    def test_variant_callers_require_dsyms_only_for_dynamic_frameworks(self):
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copy2(SCRIPTS / "ci-utils.sh", scripts)
        for helper in ("build-xcframework-slice.sh", "verify-v10-sentrycrash-objects.sh"):
            path = scripts / helper
            path.write_text("#!/bin/bash\nexit 0\n")
            path.chmod(0o755)
        assemble = scripts / "assemble-xcframework.sh"
        assemble.write_text('#!/bin/bash\nexec xcodebuild -create-xcframework "$@"\n')
        assemble.chmod(0o755)
        for name in ("build-xcframework-variant.sh", "build-xcframework-v10.sh"):
            script = scripts / name
            shutil.copy2(SCRIPTS / name, script)
            for macho in ("staticlib", "mh_dylib"):
                with self.subTest(script=name, macho=macho):
                    args = ["--sdks", "macosx", "--mach-o-type", macho]
                    if name == "build-xcframework-variant.sh":
                        args.extend(["--scheme", "Fixture"])
                    result = self.run_script(script, *args)
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertEqual("--require-debug-symbols" in json.loads(self.calls.read_text()),
                                     macho != "staticlib")

    def test_static_framework_does_not_require_dsym(self):
        (self.root / "Fixture.framework").mkdir()
        result = self.assemble("--framework-template", "Fixture.framework")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("-debug-symbols", json.loads(self.calls.read_text()))

    def test_static_library_does_not_require_dsym(self):
        (self.root / "libFixture.a").touch()
        (self.root / "headers").mkdir()
        result = self.assemble("--library-template", "libFixture.a", "--headers", "headers")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("-debug-symbols", json.loads(self.calls.read_text()))

    def test_static_library_rejects_required_dsym_option(self):
        (self.root / "libFixture.a").touch()
        (self.root / "headers").mkdir()
        result = self.assemble("--library-template", "libFixture.a", "--headers", "headers",
                               "--require-debug-symbols")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--require-debug-symbols is only supported with frameworks", result.stdout)
        self.assertFalse(self.calls.exists())

    def test_compression_preserves_contents_and_optional_signature(self):
        self.tool("codesign", '''#!/bin/bash
set -euo pipefail
if [[ "$1" == --sign ]]; then
    printf 'signed fixture' > "${@: -1}/signature"
fi
''')
        for signed in (False, True):
            with self.subTest(signed=signed):
                directory = self.root / str(signed)
                framework = directory / "Fixture with spaces.xcframework"
                framework.mkdir(parents=True)
                (framework / "payload").write_text("framework contents")
                result = self.run_script("compress-xcframework.sh", "--xcframework", framework,
                                         *(["--sign"] if signed else []))
                self.assertEqual(result.returncode, 0, result.stdout)
                archive = framework.with_suffix(".xcframework.zip")
                self.assertEqual(set(directory.iterdir()), {framework, archive})
                with zipfile.ZipFile(archive) as zipped:
                    self.assertIn(f"{framework.name}/payload", zipped.namelist())
                    self.assertEqual(f"{framework.name}/signature" in zipped.namelist(), signed)

    def stub_framework_linker(self):
        # The clean-consumer test covers real compilation and loading.
        self.env["FIXTURE_SDK"] = str(self.root / "sdk")
        (self.root / "sdk/System/Library/Frameworks/AppKit.framework").mkdir(parents=True)
        self.tool("xcrun", '''#!/usr/bin/env python3
import os, pathlib, sys
args = sys.argv[1:]
if args[0] == "--sdk" and args[-1] == "--show-sdk-path":
    print(os.environ["FIXTURE_SDK"])
elif args[0] in ("swiftc", "dsymutil"):
    output = pathlib.Path(args[args.index("-o") + 1])
    output.mkdir(exist_ok=True) if args[0] == "dsymutil" else output.touch()
elif args[0] == "lipo":
    pathlib.Path(args[args.index("-output") + 1]).touch()
elif args[0] != "strip":
    sys.exit("Unexpected tool invocation: " + repr(args))
''')

    def test_dynamic_builder_copies_prepared_inputs_without_rewriting(self):
        self.stub_framework_linker()
        headers = self.root / "headers"
        headers.mkdir()
        header = "#import <Foundation/Foundation.h>\n"
        (headers / "Fixture.h").write_text(header)
        modules = self.root / "modules"
        module = modules / "Fixture.swiftmodule"
        module.mkdir(parents=True)
        interface = "// Already prepared; SentryHeaders.Type must not be rewritten here.\n"
        (module / "arm64.swiftinterface").write_text(interface)
        resources = self.root / "resources"
        bundle = resources / "Fixture.bundle"
        bundle.mkdir(parents=True)
        (bundle / "payload").write_text("resource contents")
        library = self.root / "libFixture.a"
        library.touch()
        custom_map = 'framework module Fixture { header "Fixture.h" export * }\n'
        for sdk in ("macosx", "maccatalyst", "iphoneos"):
            for mode in ("headers-only", "modules-only", "resources-only", "prepared"):
                with self.subTest(sdk=sdk, mode=mode):
                    output = self.root / f"output-{sdk}-{mode}"
                    args = []
                    (modules / "module.modulemap").unlink(missing_ok=True)
                    if mode == "prepared":
                        (modules / "module.modulemap").write_text(custom_map)
                    if mode in ("modules-only", "prepared"):
                        args.extend(["--modules", modules])
                    if mode in ("resources-only", "prepared"):
                        args.extend(["--resources", resources])
                    result = self.run_script(
                        "build-dynamic-framework.sh", "--sdk", sdk,
                        "--static-lib", library, "--headers", headers,
                        "--output-dir", output, "--framework-name", "Fixture",
                        "--version", "1.2.3", *args)
                    self.assertEqual(result.returncode, 0, result.stdout)
                    framework = output / f"framework/Fixture/{sdk}/Fixture.framework"
                    self.assertEqual((framework / "Headers/Fixture.h").read_text(), header)
                    modulemap = (framework / "Modules/module.modulemap").read_text()
                    if mode == "prepared":
                        self.assertEqual(modulemap, custom_map)
                    else:
                        self.assertIn('umbrella header "Fixture.h"', modulemap)
                    copied_interface = framework / "Modules/Fixture.swiftmodule/arm64.swiftinterface"
                    if mode in ("modules-only", "prepared"):
                        self.assertEqual(copied_interface.read_text(), interface)
                    else:
                        self.assertFalse(copied_interface.exists())
                    resource_dir = framework if sdk == "iphoneos" else framework / "Resources"
                    payload = resource_dir / "Fixture.bundle/payload"
                    if mode in ("resources-only", "prepared"):
                        self.assertEqual(payload.read_text(), "resource contents")
                    else:
                        self.assertFalse(payload.exists())
                    if sdk != "iphoneos":
                        self.assertTrue((framework / "Modules").is_symlink())
                        self.assertTrue((framework / "Resources").is_symlink())
                    self.assertTrue(framework.with_suffix(".framework.dSYM").is_dir())

    def test_dynamic_builder_validates_optional_directories_before_replacing_output(self):
        headers = self.root / "headers"
        headers.mkdir()
        library = self.root / "libFixture.a"
        library.touch()
        output = self.root / "output"
        framework = output / "framework/Fixture/macosx/Fixture.framework"
        framework.mkdir(parents=True)
        marker = framework / "existing"
        marker.touch()
        for option in ("--modules", "--resources"):
            with self.subTest(option=option):
                result = self.run_script(
                    "build-dynamic-framework.sh", "--sdk", "macosx",
                    "--static-lib", library, "--headers", headers,
                    "--output-dir", output, "--framework-name", "Fixture",
                    "--version", "1.2.3", option, self.root / "missing")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("directory not found", result.stdout)
                self.assertTrue(marker.exists())

    def sentry_inputs(self, root):
        headers = root / "headers"
        headers.mkdir(parents=True)
        (headers / "Public.h").write_text(
            '#import "Types.h"\n#import SENTRY_HEADER(Types)\n#import <Foundation/Foundation.h>\n')
        (headers / "Types.h").write_text("typedef struct { int value; } HeaderValue;\n")
        archive = root / "Fixture.xcarchive"
        module = archive / "Products/Swift/Fixture.swiftmodule"
        module.mkdir(parents=True)
        (module.parent / "Fixture-Swift.h").write_text("@import SentryHeaders;\n")
        (module / "arm64-apple-macos.swiftinterface").write_text(
            "// swift-module-flags: -module-name Fixture\n@_exported import SentryHeaders\n")
        bundle = archive / "Products/Resources/Fixture.bundle"
        bundle.mkdir(parents=True)
        (bundle / "payload").write_text("resource contents")
        return archive, headers

    def snapshot(self, directory):
        return {str(path.relative_to(directory)): path.read_bytes()
                for path in directory.rglob("*") if path.is_file()}

    def test_preparation_rewrites_interfaces_and_preserves_inputs(self):
        archive, headers = self.sentry_inputs(self.root)
        module = archive / "Products/Swift/Fixture.swiftmodule"
        cases = [
            ("@_exported import SentryHeaders", "@_exported import Fixture"),
            ("public func legacy(_ value: SentryHeaders.HeaderValue) -> SentryHeaders.HeaderValue",
             "public func legacy(_ value: Fixture.HeaderValue) -> Fixture.HeaderValue"),
            ("public func modern(_ value: SentryHeaders::HeaderValue) -> SentryHeaders::HeaderValue",
             "public func modern(_ value: Fixture::HeaderValue) -> Fixture::HeaderValue"),
            ("public typealias MySentryHeaders = OtherSentryHeaders.HeaderValue",
             "public typealias MySentryHeaders = OtherSentryHeaders.HeaderValue"),
            ("public typealias SentryHeadersExtra = SentryHeadersExtra::HeaderValue",
             "public typealias SentryHeadersExtra = SentryHeadersExtra::HeaderValue"),
        ]
        flags = "// swift-module-flags: -module-name Fixture\n"
        original = flags + "\n".join(before for before, _ in cases) + "\n"
        expected = flags + "\n".join(after for _, after in cases) + "\n"
        for suffix in ("swiftinterface", "private.swiftinterface"):
            (module / f"arm64-apple-macos.{suffix}").write_text(original)
        for suffix in ("swiftmodule", "swiftdoc", "package.swiftinterface"):
            (module / f"arm64-apple-macos.{suffix}").write_text("not distributable")
        archive_before = self.snapshot(archive)
        headers_before = self.snapshot(headers)
        output = self.root / "prepared"
        for v10 in ("1", "0"):
            with self.subTest(v10=v10):
                self.env["SDK_V10"] = v10
                result = self.run_script(
                    "prepare-sentry-framework-inputs.sh", "--swift-archive", archive,
                    "--headers", headers, "--output-dir", output, "--framework-name", "Fixture")
                self.assertEqual(result.returncode, 0, result.stdout)
                prepared_module = output / "Modules/Fixture.swiftmodule"
                self.assertEqual(set(path.name for path in prepared_module.iterdir()), {
                    "arm64-apple-macos.swiftinterface", "arm64-apple-macos.private.swiftinterface"})
                for interface in prepared_module.iterdir():
                    self.assertEqual(interface.read_text(), expected)
                self.assertEqual((output / "Headers/Fixture-Swift.h").read_text(), "@import Fixture;\n")
                for name, contents in headers_before.items():
                    self.assertEqual((output / "Headers" / name).read_bytes(), contents)
                umbrella = (output / "Headers/SentryHeaders.h").read_text()
                self.assertIn('#import "Public.h"', umbrella)
                self.assertNotIn("Fixture-Swift.h", umbrella)
                self.assertEqual("SentryV10Configuration.h" in umbrella, v10 == "1")
                self.assertEqual((output / "Headers/SentryV10Configuration.h").exists(), v10 == "1")
                self.assertIn('umbrella header "SentryHeaders.h"',
                              (output / "Modules/module.modulemap").read_text())
                self.assertEqual((output / "Resources/Fixture.bundle/payload").read_text(), "resource contents")
                self.assertTrue((output / "Resources/PrivacyInfo.xcprivacy").is_file())
                self.assertEqual(self.snapshot(archive), archive_before)
                self.assertEqual(self.snapshot(headers), headers_before)

    def test_preparation_accepts_empty_resources_but_rejects_missing_directory(self):
        archive, headers = self.sentry_inputs(self.root)
        resources = archive / "Products/Resources"
        shutil.rmtree(resources / "Fixture.bundle")
        output = self.root / "prepared"
        args = ("--swift-archive", archive, "--headers", headers,
                "--output-dir", output, "--framework-name", "Fixture")
        result = self.run_script("prepare-sentry-framework-inputs.sh", *args)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(set(path.name for path in (output / "Resources").iterdir()),
                         {"PrivacyInfo.xcprivacy"})
        prepared_before = self.snapshot(output)
        resources.rmdir()
        result = self.run_script("prepare-sentry-framework-inputs.sh", *args)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Resources", result.stdout)
        self.assertEqual(self.snapshot(output), prepared_before)

    def test_preparation_rejects_output_overlapping_inputs(self):
        for location in ("headers", "archive", "nested", "parent", "symlink"):
            with self.subTest(location=location):
                root = self.root / location
                archive, headers = self.sentry_inputs(root)
                output = {"headers": headers, "archive": archive,
                          "nested": archive / "new/prepared", "parent": root,
                          "symlink": root / "alias"}[location]
                if location == "symlink":
                    output.symlink_to(headers, target_is_directory=True)
                archive_before = self.snapshot(archive)
                headers_before = self.snapshot(headers)
                result = self.run_script(
                    "prepare-sentry-framework-inputs.sh", "--swift-archive", archive,
                    "--headers", headers, "--output-dir", output, "--framework-name", "Fixture")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Output directory must not overlap", result.stdout)
                self.assertEqual(self.snapshot(archive), archive_before)
                self.assertEqual(self.snapshot(headers), headers_before)
                self.assertFalse((archive / "new").exists())

    def test_preparation_rejects_invalid_swift_artifacts(self):
        for invalid in ("module", "header", "interfaces", "module-name"):
            with self.subTest(invalid=invalid):
                archive, headers = self.sentry_inputs(self.root / invalid)
                module = archive / "Products/Swift/Fixture.swiftmodule"
                if invalid == "module":
                    shutil.rmtree(module)
                elif invalid == "header":
                    (module.parent / "Fixture-Swift.h").unlink()
                elif invalid == "interfaces":
                    (module / "arm64-apple-macos.swiftinterface").rename(module / "arm64-apple-macos.package.swiftinterface")
                else:
                    (module / "arm64-apple-macos.swiftinterface").write_text(
                        "// swift-module-flags: -module-name Different\n")
                output = self.root / invalid / "prepared"
                result = self.run_script(
                    "prepare-sentry-framework-inputs.sh", "--swift-archive", archive,
                    "--headers", headers, "--output-dir", output, "--framework-name", "Fixture")
                self.assertNotEqual(result.returncode, 0)
                expected = {"module": "Missing Swift artifacts", "header": "Missing Swift artifacts",
                            "interfaces": "No distributable Swift interfaces", "module-name": "Swift module name does not match"}
                self.assertIn(expected[invalid], result.stdout)
                self.assertFalse(output.exists())

    def test_builders_require_explicit_parameters_before_building(self):
        package = self.root / "package"
        package.mkdir()
        (package / "Package.swift").touch()
        headers = self.root / "headers"
        headers.mkdir()
        library = self.root / "libFixture.a"
        library.touch()
        builders = {
            "build-static-library.sh": {
                "--sdk": "macosx", "--output-dir": str(self.root / "output"),
                "--package-path": str(package), "--configuration": "Release",
                "--scheme": "Fixture", "--architecture-target": "Implementation",
            },
            "build-dynamic-framework.sh": {
                "--sdk": "macosx", "--output-dir": str(self.root / "output"),
                "--static-lib": str(library), "--headers": str(headers),
                "--framework-name": "Fixture", "--version": "1.2.3",
            },
            "prepare-sentry-framework-inputs.sh": {
                "--swift-archive": str(self.root / "archive"), "--headers": str(headers),
                "--output-dir": str(self.root / "output"), "--framework-name": "Fixture",
            },
        }
        for script, parameters in builders.items():
            for required in parameters:
                for invalid in ("omitted", "empty", "missing-value"):
                    with self.subTest(script=script, required=required, invalid=invalid):
                        args = [item for key, value in parameters.items() if key != required
                                for item in (key, value)]
                        if invalid == "empty":
                            args.extend([required, ""])
                        elif invalid == "missing-value":
                            args.append(required)
                        self.calls.unlink(missing_ok=True)
                        result = self.run_script(script, *args)
                        self.assertNotEqual(result.returncode, 0, result.stdout)
                        message = (f"Missing value for {required}" if invalid == "missing-value"
                                   else f"{required} is required")
                        self.assertIn(message, result.stdout)
                        self.assertFalse(self.calls.exists(), result.stdout)
                        self.assertFalse((self.root / "output").exists(), result.stdout)


if __name__ == "__main__":
    unittest.main()
