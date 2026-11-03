"""Regression tests for XCFramework assembly, compression and builder arguments."""

import hashlib
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

    def test_checksum_matches_final_zip_and_is_relocatable(self):
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
                checksum = archive.with_suffix(".zip.sha256")
                self.assertTrue(checksum.is_file(), result.stdout)
                digest = hashlib.sha256(archive.read_bytes()).hexdigest()
                self.assertEqual(checksum.read_text(), f"{digest}  {archive.name}\n")
                with zipfile.ZipFile(archive) as zipped:
                    self.assertIn(f"{framework.name}/payload", zipped.namelist())
                    self.assertEqual(f"{framework.name}/signature" in zipped.namelist(), signed)
                relocated = self.root / f"relocated-{signed}"
                directory.rename(relocated)
                check = subprocess.run(["shasum", "-a", "256", "-c", checksum.name], cwd=relocated,
                                       text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                self.assertEqual(check.returncode, 0, check.stdout)

    def test_framework_rewrites_legacy_and_swift64_module_qualifiers(self):
        # Exercise the real packager with textual interfaces from both compiler formats.
        # Linking is stubbed; the clean-consumer test covers real compilation and loading.
        self.env["SDK_V10"] = "0"
        self.env["FIXTURE_SDK"] = str(self.root / "sdk")
        (self.root / "sdk/System/Library/Frameworks/AppKit.framework").mkdir(parents=True)
        self.tool("xcrun", '''#!/usr/bin/env python3
import os, pathlib, sys
args = sys.argv[1:]
if args == ["--sdk", "macosx", "--show-sdk-path"]:
    print(os.environ["FIXTURE_SDK"])
elif args[0] in ("swiftc", "dsymutil"):
    output = pathlib.Path(args[args.index("-o") + 1])
    output.mkdir() if args[0] == "dsymutil" else output.touch()
elif args[0] == "lipo":
    pathlib.Path(args[args.index("-output") + 1]).touch()
elif args[0] != "strip":
    sys.exit("Unexpected tool invocation: " + repr(args))
''')
        headers = self.root / "headers"
        headers.mkdir()
        (headers / "Public.h").write_text("typedef struct { int value; } HeaderValue;\n")
        library = self.root / "libFixture.a"
        library.touch()
        archive = self.root / "Fixture.xcarchive"
        module = archive / "Products/Swift/Fixture.swiftmodule"
        module.mkdir(parents=True)
        (module.parent / "Fixture-Swift.h").write_text("@import SentryHeaders;\n")
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
        output = self.root / "output"
        result = self.run_script("build-dynamic-framework.sh", "--sdk", "macosx",
                                 "--static-lib", library, "--headers", headers,
                                 "--output-dir", output, "--framework-name", "Fixture",
                                 "--version", "1.2.3", "--swift-archive", archive)
        self.assertEqual(result.returncode, 0, result.stdout)
        framework = output / "framework/Fixture/macosx/Fixture.framework"
        for suffix in ("swiftinterface", "private.swiftinterface"):
            with self.subTest(interface=suffix):
                interface = framework / f"Modules/Fixture.swiftmodule/arm64-apple-macos.{suffix}"
                self.assertEqual(interface.read_text(), expected)

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
