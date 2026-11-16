"""Verify that SwiftPM packaging preserves the Xcode umbrella and public module surface."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent


class PrepareSentryFrameworkInputsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sentry framework inputs ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ("prepare-sentry-framework-inputs.sh", "ci-utils.sh"):
            shutil.copy2(SCRIPTS / name, scripts / name)
        self.script = scripts / "prepare-sentry-framework-inputs.sh"
        self.headers = self.root / "Sources/Sentry/Public"
        self.headers.mkdir(parents=True)
        self.umbrella = "#import <Foundation/Foundation.h>\n#import <Sentry/SentryDefines.h>\n"
        (self.headers / "Sentry.h").write_text(self.umbrella)
        self.declarations = "#if SDK_V10\nvoid v10_callback(void);\n#else\nvoid v9_callback(void);\n#endif\n"
        (self.headers / "SentryDefines.h").write_text(self.declarations)
        (self.headers / "SentryProfilingConditionals.h").write_text("// capability macros\n")
        resources = self.root / "Sources/Resources"
        resources.mkdir(parents=True)
        shutil.copy2(SCRIPTS.parent / "Sources/Resources/SentrySPM.modulemap", resources)
        (resources / "PrivacyInfo.xcprivacy").write_text("privacy fixture")
        configuration = self.root / "Sources/SentryV10Configuration/include"
        configuration.mkdir(parents=True)
        self.v10_configuration = "#ifndef SDK_V10\n#define SDK_V10 1\n#endif\n"
        (configuration / "SentryV10Configuration.h").write_text(self.v10_configuration)
        self.archive = self.root / "archive"
        swift = self.archive / "Products/Swift"
        module = swift / "Sentry.swiftmodule"
        module.mkdir(parents=True)
        self.interface = "// swift-module-flags: -module-name Sentry\n@_exported import SentryHeaders\n"
        for suffix in ("swiftinterface", "private.swiftinterface"):
            (module / f"arm64-apple-ios.{suffix}").write_text(self.interface)
        (swift / "Sentry-Swift.h").write_text("@import SentryHeaders;\n")
        (self.archive / "Products/Resources").mkdir()
        self.output = self.root / "prepared"

    def test_packaging_uses_xcode_umbrella_without_extra_public_submodules(self):
        for generation in ("0", "1", "0"):
            with self.subTest(generation=generation):
                result = subprocess.run(
                    ["bash", str(self.script), "--swift-archive", str(self.archive),
                     "--output-dir", str(self.output)],
                    env={**os.environ, "SDK_V10": generation}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                headers = self.output / "Headers"
                self.assertEqual((headers / "Sentry.h").read_text(), self.umbrella)
                expected = "void v10_callback(void);\n" if generation == "1" else self.declarations
                self.assertEqual((headers / "SentryDefines.h").read_text(), expected)
                self.assertEqual((self.headers / "SentryDefines.h").read_text(), self.declarations)
                self.assertFalse((headers / "SentryHeaders.h").exists())
                self.assertFalse((headers / "SentryV10Configuration.h").exists())
                self.assertIn('umbrella header "Sentry.h"',
                              (self.output / "Modules/module.modulemap").read_text())
                self.assertEqual((headers / "Sentry-Swift.h").read_text(), "#import <Sentry/Sentry.h>\n")
                self.assertEqual((self.headers / "Sentry.h").read_text(), self.umbrella)
                for suffix in ("swiftinterface", "private.swiftinterface"):
                    name = f"arm64-apple-ios.{suffix}"
                    self.assertEqual((self.output / "Modules/Sentry.swiftmodule" / name).read_text(),
                                     self.interface.replace("SentryHeaders", "Sentry"))
                    self.assertEqual((self.archive / "Products/Swift/Sentry.swiftmodule" / name).read_text(),
                                     self.interface)

    def test_invalid_v10_header_fails_without_publishing_partial_outputs(self):
        (self.headers / "SentryDefines.h").write_text("#if SDK_V10\n")
        result = subprocess.run(
            ["bash", str(self.script), "--swift-archive", str(self.archive),
             "--output-dir", str(self.output)],
            env={**os.environ, "SDK_V10": "1"}, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Premature EOF", result.stderr)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
