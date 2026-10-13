#!/usr/bin/env swift

// Compile and link real iOS-simulator V9 consumers. NoUIFramework must remove UIKit
// autolinking and UIApplication lifecycle observers from the recorder, not just build.
import Foundation

private let files = FileManager.default
private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

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

private func run(_ arguments: [String], in directory: URL, log: URL) throws -> String {
    try write("", to: log)
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
    process.environment = environment

    try process.run()
    process.waitUntilExit()

    try write("\(process.terminationStatus)\n", to: log.appendingPathExtension("exit-status"))
    try require(process.terminationStatus == 0, "Command failed; see \(log.path)")

    return try String(contentsOf: log, encoding: .utf8)
}

private func prepareSDK(root: URL, manifest: String) throws -> URL {
    let sdk = root.appendingPathComponent("sdk-" + manifest)
    try files.createDirectory(at: sdk, withIntermediateDirectories: true)

    let archive = root.appendingPathComponent("source.tar")
    if !files.fileExists(atPath: archive.path) {
        _ = try run(["git", "archive", "HEAD", "--output", archive.path], in: repository,
                    log: root.appendingPathComponent("archive.log"))
    }

    _ = try run(["tar", "-xf", archive.path, "-C", sdk.path], in: root,
                log: root.appendingPathComponent("extract-" + manifest + ".log"))

    // Overlay only the fix's manifests; preserve unrelated working changes outside this snapshot.
    for name in ["Package@swift-6.1.swift", "Package@swift-6.2.swift"] {
        try files.removeItem(at: sdk.appendingPathComponent(name))
        try files.copyItem(at: repository.appendingPathComponent(name), to: sdk.appendingPathComponent(name))
    }

    if manifest == "6.1" {
        try files.removeItem(at: sdk.appendingPathComponent("Package@swift-6.2.swift"))
    }

    _ = try run(["bash", "scripts/prepare-package.sh", "--remove-binary-targets", "true"], in: sdk,
                log: root.appendingPathComponent("prepare-" + manifest + ".log"))

    return sdk
}

private func test(root: URL, sdk: URL, manifest: String, noUI: Bool, sdkPath: String) throws {
    let name = manifest + (noUI ? "-no-ui" : "-ui")
    let consumer = root.appendingPathComponent(name)
    let traits = noUI ? ".defaults, \"NoUIFramework\"" : ".defaults"

    try write("""
    // swift-tools-version: 6.1
    import PackageDescription
    let package = Package(
        name: "RecorderConsumer",
        platforms: [.iOS(.v15)],
        dependencies: [.package(path: \(String(reflecting: sdk.path)), traits: [\(traits)])],
        targets: [.executableTarget(name: "RecorderConsumer", dependencies: [
            .product(name: "SentrySPM", package: "\(sdk.lastPathComponent)")
        ])]
    )
    """, to: consumer.appendingPathComponent("Package.swift"))

    // Require SDK startup linkage, but never execute the simulator binary or install handlers.
    try write("import SentrySwift\nSentrySDK.start { _ in }\n",
              to: consumer.appendingPathComponent("Sources/RecorderConsumer/main.swift"))

    let build = consumer.appendingPathComponent("build")
    let command = ["swift", "build", "--build-system", "native", "--package-path", consumer.path,
                   "--scratch-path", build.path, "--triple", "arm64-apple-ios15.0-simulator", "--sdk", sdkPath]
    _ = try run(command, in: consumer, log: root.appendingPathComponent(name + "-build.log"))

    let binOutput = try run(command + ["--show-bin-path"], in: consumer,
                            log: root.appendingPathComponent(name + "-bin-path.log"))
    let binPath = binOutput.split(separator: "\n").last.map(String.init) ?? ""
    try require(binPath.hasPrefix("/"), "Missing consumer binary path")

    let binary = URL(fileURLWithPath: binPath).appendingPathComponent("RecorderConsumer")
    let linkage = try run(["xcrun", "otool", "-L", binary.path], in: root,
                          log: root.appendingPathComponent(name + "-linkage.log"))

    let linksUIKit = linkage.contains("UIKit.framework/") || linkage.contains("libswiftUIKit.dylib")
    try testRecorderObjects(build: build, root: root, name: name, noUI: noUI)
    try require(linksUIKit != noUI, "\(name): unexpected consumer UIKit linkage")

    print("PASS \(name): consumer linkage, recorder autolinks and lifecycle symbols")
}

private func testRecorderObjects(build: URL, root: URL, name: String, noUI: Bool) throws {
    guard let enumerator = files.enumerator(at: build, includingPropertiesForKeys: nil) else {
        throw Failure(message: "Missing recorder build output")
    }

    let objects = enumerator.compactMap { $0 as? URL }.filter {
        $0.pathComponents.contains("SentryCrashV9.build") && $0.pathExtension == "o"
    }.sorted { $0.path < $1.path }

    try require(objects.contains { $0.lastPathComponent == "SentryCrash.m.o" }
                && objects.contains { $0.lastPathComponent == "SentryCrashMonitor_System.m.o" },
                "\(name): recorder objects were not compiled")

    let symbols = try run(["xcrun", "nm", "-u"] + objects.map(\.path), in: root,
                          log: root.appendingPathComponent(name + "-symbols.log"))

    let loadCommands = try run(["xcrun", "otool", "-l"] + objects.map(\.path), in: root,
                               log: root.appendingPathComponent(name + "-autolinks.log"))

    let hasLifecycleObserver = symbols.contains("_UIApplicationDidBecomeActiveNotification")
    let autolinksUIKit = loadCommands.contains("string #2 UIKit\n")
    try require(hasLifecycleObserver != noUI && autolinksUIKit != noUI,
                "\(name): unexpected recorder UIKit autolink/lifecycle observer")

    if noUI {
        try require(!symbols.contains("_UIApplication") && !symbols.contains("_OBJC_CLASS_$_UIDevice"),
                    "\(name): recorder retains UIKit symbols")
    }
}

do {
    var work: URL?
    var manifests = ["6.1", "6.2"]
    var arguments = Array(CommandLine.arguments.dropFirst())

    while !arguments.isEmpty {
        let flag = arguments.removeFirst()
        try require(!arguments.isEmpty, "Usage: test-spm-v9-no-ui-framework.swift [--work-dir|-w PATH] [--manifest|-m 6.1|6.2]")

        let value = arguments.removeFirst()
        switch flag {
        case "--work-dir", "-w": work = URL(fileURLWithPath: value).standardizedFileURL
        case "--manifest", "-m":
            try require(["6.1", "6.2"].contains(value), "Manifest must be 6.1 or 6.2")
            manifests = [value]
        default: throw Failure(message: "Unknown option \(flag)")
        }
    }
    let root = work ?? files.temporaryDirectory.appendingPathComponent("sentry-v9-no-ui-\(UUID().uuidString)")
    try require(!files.fileExists(atPath: root.path), "Work directory must not already exist: \(root.path)")
    try files.createDirectory(at: root, withIntermediateDirectories: true)

    print("Evidence: \(root.path)")

    let sdkPath = try run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], in: root,
                          log: root.appendingPathComponent("sdk-path.log")).trimmingCharacters(in: .whitespacesAndNewlines)

    for manifest in manifests {
        let sdk = try prepareSDK(root: root, manifest: manifest)
        // The UI-positive control must retain UIKit, proving these checks see recorder UI code.
        try test(root: root, sdk: sdk, manifest: manifest, noUI: false, sdkPath: sdkPath)
        try test(root: root, sdk: sdk, manifest: manifest, noUI: true, sdkPath: sdkPath)
    }

    if work == nil { try files.removeItem(at: root) }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
