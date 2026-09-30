#!/usr/bin/env swift

// Check the project edits with small fixtures, then build a dependency-free Xcode consumer
// to verify that default V9 traits do not sneak into its explicit V10 package request.

import Foundation

private let files = FileManager.default
private let scripts = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
private struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(message: message) }
}

private func write(_ text: String, to url: URL) throws {
    try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "SDK_V10")
    process.environment = environment

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

private let folder = "AAAAAAAAAAAAAAAAAAAAAAAA"
private let reference = "BBBBBBBBBBBBBBBBBBBBBBBB"
private let group = "CCCCCCCCCCCCCCCCCCCCCCCC"
private let project = "DDDDDDDDDDDDDDDDDDDDDDDD"
private let source = "EEEEEEEEEEEEEEEEEEEEEEEE"
private let product = "FFFFFFFFFFFFFFFFFFFFFFFF"
private let build = "111111111111111111111111"
private let fixture = """
// !$*UTF8*$!
{
    archiveVersion = 1;
    objects = {
        \(folder) /* package */ = {isa = PBXFileReference; lastKnownFileType = folder; path = ../package; sourceTree = SOURCE_ROOT; };
        \(source) /* sources */ = {isa = PBXFileReference; lastKnownFileType = folder; path = Sources; sourceTree = SOURCE_ROOT; };
        \(reference) = {isa = XCLocalSwiftPackageReference; relativePath = ../package; traits = (NoUIFramework, V10,); };
        \(group) = {
            isa = PBXGroup;
            children = (
                \(folder) /* package */,
                \(source) /* sources */,
            );
        };
        \(product) = {isa = XCSwiftPackageProductDependency; productName = Probe; };
        \(project) = {isa = PBXProject; mainGroup = \(group); packageReferences = (\(reference),); };
    };
    rootObject = \(project);
}
"""

private func test(_ name: String, text: String, helper: URL, root: URL,
                  succeeds: Bool = true, removes: Bool = true) throws {
    let package = root.appendingPathComponent(name + "/app/Probe.xcodeproj")
    let file = package.appendingPathComponent("project.pbxproj")
    try write(text, to: file)

    let result = try run(helper.path, [package.path])
    try require((result.status == 0) == succeeds, "\(name): \(result.output)")

    let updated = try String(contentsOf: file, encoding: .utf8)
    if !succeeds || !removes {
        try require(updated == text, "\(name): unexpected file change")
    } else {
        try require(!updated.contains(folder), "\(name): folder remains")
        try require(updated.contains(reference) && updated.contains(source) && updated.contains(product),
                    "\(name): removed unrelated project objects")
        let again = try run(helper.path, [package.path])
        try require(again.status == 0 && (try Data(contentsOf: file)) == Data(updated.utf8),
                    "\(name): correction is not idempotent")
    }

    print("PASS \(name)")
}

private func createXcodeFixture(root: URL) throws -> URL {
    let package = root.appendingPathComponent("integration/package")
    let app = root.appendingPathComponent("integration/app")
    try write("""
    // swift-tools-version: 6.2
    import PackageDescription
    let package = Package(
        name: "Probe",
        products: [.library(name: "Probe", targets: ["Probe"])],
        traits: [.default(enabledTraits: ["V9"]), .init(name: "V9"), .init(name: "V10"), .init(name: "NoUIFramework")],
        targets: [.target(name: "Probe")]
    )
    """, to: package.appendingPathComponent("Package.swift"))
    try write("""
    public func checkTraits() -> String {
    #if V9
        return "unexpected V9"
    #elseif V10 && NoUIFramework
        return "V10,NoUIFramework"
    #else
        return "missing traits"
    #endif
    }
    """, to: package.appendingPathComponent("Sources/Probe/Probe.swift"))
    try write("import Probe\nprint(checkTraits())\n", to: app.appendingPathComponent("Sources/main.swift"))
    let spec = app.appendingPathComponent("probe.yml")
    try write("""
    name: ProbeApp
    packages:
      Probe:
        path: ../package
        traits: [V10, NoUIFramework]
    targets:
      ProbeApp:
        type: tool
        platform: macOS
        deploymentTarget: "12.0"
        sources: [Sources]
        dependencies:
          - package: Probe
            product: Probe
    schemes:
      ProbeApp:
        build:
          targets:
            ProbeApp: all
    """, to: spec)
    return spec
}

private func testXcodeConsumer(helper: URL, root: URL) throws {
    let spec = try createXcodeFixture(root: root)
    let app = spec.deletingLastPathComponent()
    let generated = try run("/usr/bin/env", ["xcodegen", "--spec", spec.path])
    try require(generated.status == 0, generated.output)

    let project = app.appendingPathComponent("ProbeApp.xcodeproj")
    let corrected = try run(helper.path, [project.path])
    try require(corrected.status == 0, corrected.output)

    let derived = root.appendingPathComponent("integration/derived-data")
    let result = try run("/usr/bin/xcodebuild", [
        "-project", project.path, "-scheme", "ProbeApp", "-destination", "platform=macOS",
        "-derivedDataPath", derived.path, "CODE_SIGNING_ALLOWED=NO", "build"
    ])
    try write(result.output, to: root.appendingPathComponent("integration-build.log"))
    try require(result.status == 0, "Xcode trait consumer failed:\n\(result.output)")

    let binary = try run(derived.appendingPathComponent("Build/Products/Debug/ProbeApp").path, [])
    try require(binary.status == 0 && binary.output.trimmingCharacters(in: .whitespacesAndNewlines) == "V10,NoUIFramework",
                "Xcode selected incorrect package traits: \(binary.output)")

    print("PASS actual Xcode local-package trait consumer")
}

do {
    let root = files.temporaryDirectory.appendingPathComponent("v10-package-folders-\(UUID().uuidString)")
    try files.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? files.removeItem(at: root) }
    let helper = root.appendingPathComponent("remove-folders")
    let compiled = try run("/usr/bin/env", ["swiftc", scripts.appendingPathComponent("remove-v10-package-folder-references.swift").path, "-o", helper.path])

    try require(compiled.status == 0, compiled.output)
    try test("duplicate", text: fixture, helper: helper, root: root)
    try test("multiline", text: fixture.replacingOccurrences(of: "path = ../package;", with: "\npath = ../package;\n"), helper: helper, root: root)
    try test("quoted-path", text: fixture.replacingOccurrences(of: "../package", with: "\"../package with spaces\""), helper: helper, root: root)
    try test("normalized-path", text: fixture.replacingOccurrences(of: "path = ../package;", with: "path = ../other/../package;"), helper: helper, root: root)
    try test("v9-unchanged", text: fixture.replacingOccurrences(of: "NoUIFramework, V10,", with: "NoUIFramework, V9,"), helper: helper, root: root, removes: false)
    try test("default-unchanged", text: fixture.replacingOccurrences(of: "traits = (NoUIFramework, V10,);", with: ""), helper: helper, root: root, removes: false)
    try test("remote-unchanged", text: fixture.replacingOccurrences(of: "XCLocalSwiftPackageReference", with: "XCRemoteSwiftPackageReference"), helper: helper, root: root, removes: false)
    try test("unrelated-folder", text: fixture.replacingOccurrences(of: "path = ../package;", with: "path = ../unrelated;"), helper: helper, root: root, removes: false)
    try test("build-input-rejected", text: fixture.replacingOccurrences(of: "objects = {", with: "objects = { \(build) = {isa = PBXBuildFile; fileRef = \(folder);};"), helper: helper, root: root, succeeds: false)
    try test("bad-traits", text: fixture.replacingOccurrences(of: "traits = (NoUIFramework, V10,);", with: "traits = V10;"), helper: helper, root: root, succeeds: false)
    try test("missing-reference", text: fixture.replacingOccurrences(of: "packageReferences = (\(reference),);", with: "packageReferences = (\(build),);"), helper: helper, root: root, succeeds: false)
    try test("variable-path", text: fixture.replacingOccurrences(of: "../package", with: "\"$(SRCROOT)/package\""), helper: helper, root: root, succeeds: false)
    try test("malformed-project", text: "not a plist", helper: helper, root: root, succeeds: false)
    try testXcodeConsumer(helper: helper, root: root)

    print("All 13 project fixtures and the Xcode trait consumer passed")
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
