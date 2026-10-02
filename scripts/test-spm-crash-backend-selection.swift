#!/usr/bin/env swift

// Build real SDK consumers with valid and invalid crash backend selections. Negative tests
// pass only on the expected intentional diagnostic, not an unrelated compiler failure.
// SDK copies and build logs stay outside the checkout but with --work-dir 
// you keep them where you like for review.

import Foundation

private let files = FileManager.default
private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
private let missingBackendDiagnostic = "Sentry requires a crash backend: enable the V9 or V10 package trait."
private let mutuallyExclusiveTraitsDiagnostic = "Sentry crash backend traits V9 and V10 are mutually exclusive: enable only one."

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
    var expectedDiagnostic: String?
}

private let cases = [
    BuildCase(name: "no-backend", traits: [], expectedDiagnostic: missingBackendDiagnostic),
    BuildCase(name: "both-backends", traits: ["V9", "V10"], expectedDiagnostic: mutuallyExclusiveTraitsDiagnostic),
    BuildCase(name: "both-backends-environment", traits: ["V9", "V10"], environmentV10: true, expectedDiagnostic: mutuallyExclusiveTraitsDiagnostic),
    BuildCase(name: "default-v9", traits: nil),
    BuildCase(name: "default-v9-native", traits: nil, nativeBuild: true),
    BuildCase(name: "explicit-v9", traits: ["V9"]),
    BuildCase(name: "trait-v10", traits: ["V10"]),
    BuildCase(name: "no-ui-only", traits: ["NoUIFramework"], expectedDiagnostic: missingBackendDiagnostic),
    BuildCase(name: "no-ui-v9", traits: ["V9", "NoUIFramework"]),
    BuildCase(name: "no-ui-defaults", traits: ["NoUIFramework"], includeDefaultTraits: true),
    BuildCase(name: "no-ui-v10", traits: ["V10", "NoUIFramework"]),
    BuildCase(name: "environment-v10", traits: [], environmentV10: true),
    BuildCase(name: "environment-v10-defaults", traits: nil, environmentV10: true),
    BuildCase(name: "base-v9", traits: nil, baseManifest: true),
    BuildCase(name: "base-v9-native", traits: nil, baseManifest: true, nativeBuild: true),
    BuildCase(name: "base-v10", traits: nil, environmentV10: true, baseManifest: true),
    BuildCase(name: "no-backend-swift61", traits: [], swift61Manifest: true, expectedDiagnostic: missingBackendDiagnostic),
    BuildCase(name: "both-backends-swift61", traits: ["V9", "V10"], swift61Manifest: true, expectedDiagnostic: mutuallyExclusiveTraitsDiagnostic),
    BuildCase(name: "trait-v10-swift61", traits: ["V10"], swift61Manifest: true),
    BuildCase(name: "shared-testapp-default-v9", traits: nil, sharedTestApp: true),
    BuildCase(name: "shared-testapp-v10", traits: ["V10"], sharedTestApp: true),
    BuildCase(name: "shared-testapp-both-backends", traits: ["V9", "V10"], sharedTestApp: true, expectedDiagnostic: mutuallyExclusiveTraitsDiagnostic)
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
    let archive = root.appendingPathComponent("source.tar")
    if !files.fileExists(atPath: archive.path) {
        let status = try run(["git", "archive", "HEAD", "--output", archive.path], in: repository,
                             log: root.appendingPathComponent("archive.log"))
        try require(status == 0, "SDK archive failed; see \(root.path)/archive.log")
    }

    let extracted = try run(["tar", "-xf", archive.path, "-C", sdk.path], in: root,
                            log: root.appendingPathComponent(name + "-extract.log"))
    try require(extracted == 0, "SDK extraction failed")

    // Use the current diagnostic/manifests, but exclude unrelated working-tree changes.
    for path in [
        "Package.swift", 
        "Package@swift-6.1.swift", 
        "Package@swift-6.2.swift", 
        "TestApps/SentrySampleShared/Package.swift",
        "Sources/Sentry/include/SentrySwift.h",
        "Sources/SentryCrashV9Swift/SentryCrashV9Dependencies.swift",
        "Sources/SentryCrash/Installations/SentryCrashInstallation.m",
        "Sources/SentryCrash/Recording/SentryCrash.m",
        "Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.m",
        "Sources/Sentry/include/SentryPrivate.h", 
        "Sources/Sentry/include/SentryCrashBackendSelection.h",
        "Sources/Sentry/SentryDummyPrivateEmptyClass.m",
        "Sources/Sentry/Public/SentryDefines.h", 
        "Sources/SentryV10Configuration/include/SentryV10Configuration.h",
        "Sources/SentryV10Configuration/SentryV10Configuration.c"] {
        if files.fileExists(atPath: sdk.appendingPathComponent(path).path) {
            try files.removeItem(at: sdk.appendingPathComponent(path))
        }
        try files.createDirectory(at: sdk.appendingPathComponent(path).deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: repository.appendingPathComponent(path), to: sdk.appendingPathComponent(path))
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
    let output = try String(contentsOf: log, encoding: .utf8)

    if let expectedDiagnostic = scenario.expectedDiagnostic {
        try require(status != 0 && output.contains(expectedDiagnostic) && !files.fileExists(atPath: binary.path),
                    "\(scenario.name): expected the intentional backend diagnostic and no executable; see \(log.path)")
    } else {
        try require(status == 0 && !output.contains(missingBackendDiagnostic) && !output.contains(mutuallyExclusiveTraitsDiagnostic) && files.fileExists(atPath: binary.path),
                    "\(scenario.name): expected a linked consumer; see \(log.path)")
    }

    print("PASS \(scenario.name)")
}

private func testHeaderContexts(root: URL) throws {
    let source = root.appendingPathComponent("monolithic.m")

    try write("""
    #import "SentryDefines.h"
    #import "SentryCrashBackendSelection.h"
    #if SDK_V10 != EXPECTED_VERSION
    #error "A visible SwiftPM configuration header changed the monolithic SDK version."
    #endif
    """, to: source)

    let contexts: [(name: String, version: Int, flags: [String])] = [
        ("monolithic-v9", 0, []),
        ("monolithic-v10", 1, ["-DSDK_V10=1"]),
        ("package-v9-compiler", 0, ["-DSWIFT_PACKAGE=1", "-DSENTRY_SWIFTPM_BACKEND_TRAITS=1", "-DSENTRY_SWIFTPM_V9=1"]),
        ("package-v9-consumer", 0, ["-DSWIFT_PACKAGE=1", "-I", repository.appendingPathComponent("Sources/SentryCrashV9Headers/include").path])
    ]

    for context in contexts {
        // The V10 configuration header is deliberately visible in every case. It must not
        // override monolithic headers, explicit V9 compilation or a V9 consumer's graph.
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
