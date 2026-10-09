#!/usr/bin/env swift

// Build real SDK consumers with temporary development selection before V10 separation.
// Absent development V10 selects V9, including empty and NoUI-only declarations.
// SDK copies and build logs stay outside the checkout but with --work-dir 
// you keep them where you like for review.

import Foundation

private let files = FileManager.default
private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

private struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct BuildCase {
    let name: String
    let traits: [String]?
    var includeDefaultTraits = false
    var environmentV10 = false
    var baseManifest = false
    var swift61Manifest = false
    var nativeBuild = false
    var sharedTestApp = false
}

private let cases = [
    BuildCase(name: "disabled-defaults-v9", traits: []),
    BuildCase(name: "default-v9", traits: nil),
    BuildCase(name: "default-v9-native", traits: nil, nativeBuild: true),
    BuildCase(name: "trait-v10", traits: ["V10"]),
    BuildCase(name: "no-ui-only", traits: ["NoUIFramework"]),
    BuildCase(name: "no-ui-defaults", traits: ["NoUIFramework"], includeDefaultTraits: true),
    BuildCase(name: "no-ui-v10", traits: ["V10", "NoUIFramework"]),
    BuildCase(name: "environment-v10", traits: [], environmentV10: true),
    BuildCase(name: "environment-v10-defaults", traits: nil, environmentV10: true),
    BuildCase(name: "base-v9", traits: nil, baseManifest: true),
    BuildCase(name: "base-v9-native", traits: nil, baseManifest: true, nativeBuild: true),
    BuildCase(name: "base-v10", traits: nil, environmentV10: true, baseManifest: true),
    BuildCase(name: "disabled-defaults-v9-swift61", traits: [], swift61Manifest: true, nativeBuild: true),
    BuildCase(name: "no-ui-only-swift61", traits: ["NoUIFramework"], swift61Manifest: true, nativeBuild: true),
    BuildCase(name: "environment-v10-swift61", traits: [], environmentV10: true, swift61Manifest: true, nativeBuild: true),
    BuildCase(name: "shared-testapp-default-v9", traits: nil, sharedTestApp: true),
    BuildCase(name: "shared-testapp-v10", traits: ["V10"], sharedTestApp: true),
    BuildCase(name: "shared-testapp-environment-v10-swift61", traits: [], environmentV10: true, swift61Manifest: true, nativeBuild: true, sharedTestApp: true)
]

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(message: message) }
}

private func write(_ text: String, to url: URL) throws {
    try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func run(_ arguments: [String], in directory: URL, log: URL, v10: Bool = false) throws -> Int32 {
    try files.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: log)

    let output = try FileHandle(forWritingTo: log)
    defer { try? output.close() }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.currentDirectoryURL = directory
    process.standardOutput = output
    process.standardError = output

    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "SDK_V10")
    if v10 { environment["SDK_V10"] = "1" }
    process.environment = environment

    try process.run()
    process.waitUntilExit()

    try write("\(process.terminationStatus)\n", to: log.appendingPathExtension("exit-status"))

    return process.terminationStatus
}

private func prepareSDK(root: URL, scenario: BuildCase) throws -> URL {
    let name = scenario.baseManifest ? "base-sdk" : (scenario.swift61Manifest ? "swift61-sdk" : "sdk")
    let sdk = root.appendingPathComponent(name)
    if files.fileExists(atPath: sdk.path) { return sdk }

    try files.createDirectory(at: sdk, withIntermediateDirectories: true)
    // Copy current tracked and non-ignored new files, including local edits and deletions.
    // Build products and Git metadata stay outside the disposable SDK copy.
    let inventory = root.appendingPathComponent(name + "-files.log")
    let status = try run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                         in: repository, log: inventory)
    try require(status == 0, "SDK file inventory failed; see \(inventory.path)")
    let paths = String(decoding: try Data(contentsOf: inventory), as: UTF8.self).split(separator: "\0")
    for path in Set(paths.map(String.init)) {
        let source = repository.appendingPathComponent(path)
        guard files.fileExists(atPath: source.path) else { continue }
        let destination = sdk.appendingPathComponent(path)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: source, to: destination)
    }

    if scenario.baseManifest {
        for manifest in ["Package@swift-6.1.swift", "Package@swift-6.2.swift"] {
            try files.removeItem(at: sdk.appendingPathComponent(manifest))
        }
    } else if scenario.swift61Manifest {
        try files.removeItem(at: sdk.appendingPathComponent("Package@swift-6.2.swift"))
    }

    let prepared = try run(["bash", "scripts/prepare-package.sh", "--remove-binary-targets", "true"], in: sdk,
                           log: root.appendingPathComponent(name + "-prepare.log"))
    try require(prepared == 0, "SDK preparation failed")

    return sdk
}

private func test(_ scenario: BuildCase, root: URL) throws {
    let sdk = try prepareSDK(root: root, scenario: scenario)
    let consumer = root.appendingPathComponent(scenario.name)
    let traits = scenario.traits.map { names in
        let entries = names.map { String(reflecting: $0) } + (scenario.includeDefaultTraits ? [".defaults"] : [])
        return ", traits: [\(entries.joined(separator: ", "))]"
    } ?? ""
    let dependency = scenario.sharedTestApp ? sdk.appendingPathComponent("TestApps/SentrySampleShared") : sdk
    let product = scenario.sharedTestApp ? "SentrySampleShared" : (scenario.environmentV10 ? "Sentry" : "SentrySPM")

    try write("""
    // swift-tools-version: \(scenario.nativeBuild ? "6.1" : "6.2")
    import PackageDescription
    let package = Package(
        name: "BackendConsumer",
        platforms: [.macOS(.v12)],
        dependencies: [.package(path: \(String(reflecting: dependency.path))\(traits))],
        targets: [.executableTarget(name: "BackendConsumer", dependencies: [
            .product(name: "\(product)", package: "\(dependency.lastPathComponent)")
        ])]
    )
    """, to: consumer.appendingPathComponent("Package.swift"))

    // Referencing SDK startup also exercises the backend registration linkage. Do not run
    // startup here; these are compile/link contract checks, not SDK runtime tests.
    let v10 = scenario.environmentV10 || scenario.traits?.contains("V10") == true
    let publicHeaderCheck = v10 ? "import SentryHeaders\nlet _: SentryBeforeSendTransactionCallback = { $0 }\n" : ""
    let sharedImport = scenario.sharedTestApp ? "import SentrySampleShared\nlet _ = SentrySDKWrapper.shared\n" : ""
    try write("import SentrySwift\n\(sharedImport)\(publicHeaderCheck)SentrySDK.start { _ in }\n", to: consumer.appendingPathComponent("Sources/BackendConsumer/main.swift"))

    var command = ["swift", "build", "--package-path", consumer.path, "--scratch-path",
                   consumer.appendingPathComponent("build").path]
    if scenario.nativeBuild { command += ["--build-system", "native"] }
    let pathLog = root.appendingPathComponent(scenario.name + "-bin-path.log")
    let pathStatus = try run(command + ["--show-bin-path"], in: consumer, log: pathLog, v10: scenario.environmentV10)
    let binPath = try String(contentsOf: pathLog, encoding: .utf8)
        .split(separator: "\n").last.map(String.init) ?? ""
    try require(pathStatus == 0 && binPath.hasPrefix("/"), "Could not determine consumer binary path; see \(pathLog.path)")

    let binary = URL(fileURLWithPath: binPath).appendingPathComponent("BackendConsumer")
    let log = root.appendingPathComponent(scenario.name + ".log")
    let status = try run(command + ["-v"], in: consumer, log: log, v10: scenario.environmentV10)
    try require(status == 0 && files.fileExists(atPath: binary.path),
                "\(scenario.name): expected a linked consumer; see \(log.path)")
    if v10 {
        let auditLog = root.appendingPathComponent(scenario.name + "-object-audit.log")
        let auditStatus = try run(["swift", repository.appendingPathComponent("scripts/verify-v10-empty-objects.swift").path,
                                   "--build-path", consumer.appendingPathComponent("build").path,
                                   "--build-log", log.path, "--source-root", sdk.path], in: root, log: auditLog)
        try require(auditStatus == 0, "\(scenario.name): empty-object audit failed; see \(auditLog.path)")
    }

    print("PASS \(scenario.name)")
}

private func testHeaderContexts(root: URL) throws {
    let source = root.appendingPathComponent("monolithic.m")

    try write("""
    #import "SentryDefines.h"
    #if SDK_V10 != EXPECTED_VERSION
    #error "A visible SwiftPM configuration header changed the monolithic SDK version."
    #endif
    """, to: source)

    let contexts: [(name: String, version: Int, flags: [String])] = [
        ("monolithic-v9", 0, []),
        ("monolithic-v10", 1, ["-DSDK_V10=1"])
    ]

    for context in contexts {
        // The V10 configuration header is deliberately visible in every case. It must not
        // override monolithic headers. Package consumers use their actual selected graph.
        var command = ["xcrun", "--sdk", "macosx", "clang", "-fsyntax-only", "-x", "objective-c",
                       "-fblocks", "-fmodules", "-fmodule-name=Sentry", "-DEXPECTED_VERSION=\(context.version)"] + context.flags

        for path in ["Sources/Sentry/Public", "Sources/Sentry/include", "Sources/SentryV10Configuration/include"] {
            command += ["-I", repository.appendingPathComponent(path).path]
        }

        let log = root.appendingPathComponent(context.name + ".log")
        let status = try run(command + [source.path], in: root, log: log)

        try require(status == 0, "Header version changed; see \(log.path)")

        print("PASS \(context.name) headers")
    }
}

do {
    var work: URL?
    var selected: String?
    var arguments = Array(CommandLine.arguments.dropFirst())

    while !arguments.isEmpty {
        let flag = arguments.removeFirst()
        try require(!arguments.isEmpty, "Usage: test-spm-crash-backend-selection.swift [--work-dir|-w PATH] [--case|-c NAME]")
        let value = arguments.removeFirst()

        switch flag {
        case "--work-dir", "-w": work = URL(fileURLWithPath: value).standardizedFileURL
        case "--case", "-c": selected = value
        default: throw Failure(message: "Unknown option \(flag)")
        }
    }

    let root = work ?? files.temporaryDirectory.appendingPathComponent("sentry-backend-selection-\(UUID().uuidString)")
    try require(!files.fileExists(atPath: root.path), "Work directory must not already exist: \(root.path)")

    let requested = cases.filter { selected == nil || $0.name == selected }
    try require(!requested.isEmpty, "Unknown case \(selected ?? "")")
    try files.createDirectory(at: root, withIntermediateDirectories: true)
    print("Evidence: \(root.path)")

    for scenario in requested { try test(scenario, root: root) }

    if selected == nil { try testHeaderContexts(root: root) }

    print("All \(requested.count) backend-selection consumer builds passed")

    if work == nil { try files.removeItem(at: root) }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
