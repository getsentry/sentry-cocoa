"""Build a tiny source package and consume its single packaged XCFramework."""

from itertools import product
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent


class PublicHeaderImportTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="sentry public headers ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_public_headers_compile_without_rewriting(self):
        public = SCRIPTS.parent / "Sources/Sentry/Public"
        configuration = SCRIPTS.parent / "Sources/SentryV10Configuration/include"
        for sdk, target in (("macosx", "arm64-apple-macosx11.0"),
                            ("iphoneos", "arm64-apple-ios15.0")):
            sysroot = subprocess.check_output(
                ["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
            for version, layout in product((9, 10), ("source", "Sentry", "SentryWithoutUIKit", "SentrySwift")):
                directory = self.root / f"{sdk}-{version}-{layout}"
                headers = (directory / "include" if layout == "source"
                           else directory / f"{layout}.framework/Headers")
                shutil.copytree(public, headers)
                public_headers = sorted(headers.glob("*.h"))
                module_name = "SentryHeaders" if layout == "source" else layout
                modules = headers if layout == "source" else headers.parent / "Modules"
                modules.mkdir(exist_ok=True)
                flags = []
                if layout == "source":
                    flags = ["-I", str(headers), "-DSWIFT_PACKAGE=1"]
                    if version == 10:
                        flags += ["-I", str(configuration)]
                else:
                    flags = ["-F", str(directory)]
                if layout in ("Sentry", "SentryWithoutUIKit"):
                    # Existing framework builds select the generation explicitly, even if
                    # the separate SwiftPM configuration header happens to be visible.
                    flags += [f"-DSDK_V10={int(version == 10)}", "-I", str(configuration)]
                    umbrella = f"{layout}.h"
                    shutil.copy(SCRIPTS.parent / f"Sources/Resources/{layout}.modulemap",
                                modules / "module.modulemap")
                    if layout == "Sentry":
                        flags += ["-Werror=quoted-include-in-framework-header"]
                    else:
                        flags += ["-DSENTRY_NO_UI_FRAMEWORK=1"]
                else:
                    umbrella = "ConsumerHeaders.h"
                    imports = ""
                    if layout == "SentrySwift" and version == 10:
                        shutil.copy(configuration / "SentryV10Configuration.h", headers)
                        imports = '#import "SentryV10Configuration.h"\n'
                    imports += "".join(f'#import "{header.name}"\n' for header in public_headers)
                    (headers / umbrella).write_text(imports)
                    prefix = "" if layout == "source" else "framework "
                    (modules / "module.modulemap").write_text(
                        f'{prefix}module {module_name} {{ umbrella header "{umbrella}" '
                        'export * module * { export * } }\n')
                for language, use_modules in product(("objective-c", "objective-c++"), (False, True)):
                    with self.subTest(sdk=sdk, version=version, layout=layout,
                                      language=language, modules=use_modules):
                        if use_modules:
                            include = f"@import {module_name};\n"
                        elif layout == "source":
                            include = f'#import "{umbrella}"\n'
                        else:
                            include = f"#import <{module_name}/{umbrella}>\n"
                        source = directory / "consumer.m"
                        source.write_text(include + f'''#if SDK_V10 != {int(version == 10)}
#error Incorrect SDK generation
#endif
SentryLevel level = kSentryLevelInfo;
''')
                        args = ["xcrun", "clang", "-fsyntax-only", "-x", language,
                                "-fobjc-arc", "-fblocks", "-target", target, "-isysroot", sysroot,
                                "-Wno-deprecated-declarations", *flags]
                        if use_modules:
                            args += ["-fmodules", "-fcxx-modules",
                                     "-fmodules-cache-path=" + str(self.root / "cache")]
                        else:
                            args += ["-fno-modules"]
                        result = subprocess.run(args + [str(source)], text=True,
                                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                                timeout=90)
                        self.assertEqual(result.returncode, 0, result.stdout)


class SwiftPMFrameworkPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="sentry packaged framework ")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.package = cls.root / "producer"
        cls.build = cls.root / "build"
        cls.env = {**os.environ, "SDK_V10": "1", "GITHUB_ACTIONS": "false"}
        files = {
            "Package.swift": '''// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Fixture", platforms: [.iOS(.v15), .macOS(.v10_15)],
    products: [.library(name: "Fixture", targets: ["Implementation"])],
    targets: [
        .target(name: "SentryHeaders", publicHeadersPath: "include"),
        .target(name: "SentrySwift", dependencies: ["SentryHeaders"],
                resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "Implementation", dependencies: ["SentrySwift"])
    ])
''',
            "Sources/SentryHeaders/include/SentryDefines.h": '''#pragma once
#define SENTRY_HEADER_STRINGIFY(file) #file
#define SENTRY_HEADER(file) SENTRY_HEADER_STRINGIFY(file.h)
#if SDK_V10
#define SELECTED_VERSION 10
#else
#define SELECTED_VERSION 9
#endif
''',
            "Sources/SentryHeaders/include/Types.h": '''#pragma once
#import "SentryDefines.h"
typedef struct { int value; } HeaderValue;
''',
            "Sources/SentryHeaders/include/Public.h": '''#pragma once
#import "SentryDefines.h"
#import SENTRY_HEADER(Types)
''',
            "Sources/SentryHeaders/empty.c": "void headers_marker(void) {}\n",
            "Sources/SentrySwift/SDK.swift": '''import Foundation
@_exported import SentryHeaders
public func value(_ input: HeaderValue) -> Int32 { input.value }
@_spi(Private) public func privateValue() -> Int32 { 42 }
@objc public final class PublicSDK: NSObject {
    @objc public static func answer() -> Int32 { 42 }
    public static func hasPrivacyResource() -> Bool {
        Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil
    }
}
''',
            "Sources/SentrySwift/PrivacyInfo.xcprivacy": '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict/></plist>
''',
            "Sources/Implementation/empty.c": "void implementation_marker(void) {}\n",
            "Sources/Implementation/include/Implementation.h": "void implementation_marker(void);\n",
        }
        for relative, content in files.items():
            path = cls.package / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        # Match the SDK's public-header path for interface verification.
        public = cls.package / "Sources/Sentry/Public"
        public.parent.mkdir(parents=True)
        public.symlink_to(cls.package / "Sources/SentryHeaders/include", target_is_directory=True)
        cls.run_tool([
            str(SCRIPTS / "build-static-library.sh"), "--sdk", "macosx",
            "--configuration", "Release", "--scheme", "Fixture", "--architecture-target", "SentrySwift",
            "--package-path", str(cls.package), "--output-dir", str(cls.build),
        ], "archive")
        cls.archive = cls.build / "archive/Fixture/macosx.xcarchive"
        prepared = cls.build / "prepared/SentrySwift/macosx"
        cls.run_tool([
            str(SCRIPTS / "prepare-sentry-framework-inputs.sh"),
            "--swift-archive", str(cls.archive),
            "--headers", str(public),
            "--output-dir", str(prepared),
            "--framework-name", "SentrySwift",
        ], "prepare")
        cls.run_tool([
            str(SCRIPTS / "build-dynamic-framework.sh"),
            "--sdk", "macosx",
            "--version", "1.2.3",
            "--static-lib", str(cls.build / "lib/Fixture/macosx/libFixture-Debug.a"),
            "--headers", str(prepared / "Headers"),
            "--modules", str(prepared / "Modules"),
            "--resources", str(prepared / "Resources"),
            "--output-dir", str(cls.build),
            "--framework-name", "SentrySwift",
        ], "framework")
        cls.artifact = cls.root / "distribution/SentrySwift.xcframework"
        cls.artifact.parent.mkdir()
        cls.run_tool([
            str(SCRIPTS / "assemble-xcframework.sh"), "--sdks", "macosx",
            "--framework-template", str(cls.build / "framework/SentrySwift/macosx/SentrySwift.framework"),
            "--output", str(cls.artifact), "--require-debug-symbols",
        ], "assemble")
        # The consumer must work after producer sources, intermediates and modules disappear.
        shutil.rmtree(cls.package)
        shutil.rmtree(cls.build)

    @classmethod
    def run_tool(cls, args, label, cwd=None, env=None):
        log = cls.root / (label + ".log")
        with log.open("w") as output:
            result = subprocess.run(args, env={**cls.env, **(env or {})}, cwd=cwd, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=180)
        if result.returncode:
            raise AssertionError(f"{label} failed:\n{log.read_text()[-12000:]}")

    def test_standalone_binary_target_imports_links_and_runs(self):
        consumer = self.root / "consumer"
        sources = consumer / "Sources/Consumer"
        sources.mkdir(parents=True)
        (consumer / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v10_15)], targets: [
    .binaryTarget(name: "SentrySwift", path: "../distribution/SentrySwift.xcframework"),
    .executableTarget(name: "Consumer", dependencies: ["SentrySwift"])
])
''')
        (sources / "main.swift").write_text('''@_spi(Private) import SentrySwift
precondition(value(HeaderValue(value: 42)) == 42)
precondition(privateValue() == 42)
precondition(PublicSDK.answer() == 42)
precondition(PublicSDK.hasPrivacyResource())
precondition(SELECTED_VERSION == 10)
''')
        derived = self.root / "consumer-build"
        self.run_tool([
            "xcodebuild", "build", "-workspace", str(consumer), "-scheme", "Consumer",
            "-configuration", "Release", "-destination", "platform=macOS",
            "-derivedDataPath", str(derived), "CODE_SIGNING_ALLOWED=NO",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES",
        ], "consumer")
        # A CLI target has no app bundle to embed frameworks in. Load the distributable slice.
        framework = next(self.artifact.glob("*/SentrySwift.framework"))
        self.run_tool([str(derived / "Build/Products/Release/Consumer")], "run-consumer",
                      env={"DYLD_FRAMEWORK_PATH": str(framework.parent)})

    def test_framework_preserves_spi_resources_and_objc_header(self):
        framework = next(self.artifact.glob("*/SentrySwift.framework"))
        module = framework / "Modules/SentrySwift.swiftmodule"
        self.assertTrue(list(module.glob("*.private.swiftinterface")))
        self.assertFalse(list(module.glob("*.swiftmodule")))
        self.assertFalse(list(module.glob("*.package.swiftinterface")))
        for interface in module.glob("*.swiftinterface"):
            self.assertNotIn("SentryHeaders", interface.read_text())
        bundle = framework / "Resources/Fixture_SentrySwift.bundle"
        self.assertTrue(list(bundle.rglob("PrivacyInfo.xcprivacy")))
        self.assertTrue((framework / "Resources/PrivacyInfo.xcprivacy").is_file())
        source = self.root / "consumer.m"
        source.write_text('''#import <SentrySwift/SentrySwift-Swift.h>
int answer(void) { return [PublicSDK answer]; }
''')
        self.run_tool([
            "xcrun", "--sdk", "macosx", "clang", "-fsyntax-only", "-fmodules",
            "-F", str(framework.parent), "-fmodules-cache-path=" + str(self.root / "clang-cache"),
            str(source),
        ], "objc-consumer")


if __name__ == "__main__":
    unittest.main()
