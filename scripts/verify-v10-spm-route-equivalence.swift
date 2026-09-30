#!/usr/bin/env swift

// Enabling V10 through SDK_V10, a package trait, or the base manifest should select the same
// SDK sources and crash backend. Compare those choices so a different setup doesn't change
// what code consumers build.

import Foundation

private struct PackageDescription: Decodable {
    let targets: [Target]

    struct Target: Decodable {
        let name: String
        let path: String
        let sources: [String]?
        let targetDependencies: [String]?
        let productDependencies: [String]?

        enum CodingKeys: String, CodingKey {
            case name
            case path
            case sources
            case targetDependencies = "target_dependencies"
            case productDependencies = "product_dependencies"
        }
    }
}

private struct TargetContents: Equatable {
    let sources: Set<String>
    let targetDependencies: Set<String>
    let productDependencies: Set<String>
}

private enum Route: String, CaseIterable {
    case environment
    case trait
    case baseManifest = "base-manifest"
}

private let fileManager = FileManager.default
private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .standardizedFileURL
private let comparedTargets = ["SentrySwift", "SentryObjCInternal"]
private let v9OnlySwiftSources: Set<String> = [
    "Integrations/SentryCrash/SentryCrashBridge.swift",
    "Integrations/SentryCrash/SentryCrashInstallationReporter.swift",
    "Integrations/SentryCrash/SentryCrashIntegration.swift",
    "SentryCrash/SentryCrashSwift.swift",
    "SentryCrash/SentryDefaultCrashReporter.swift"
]
private let v9AdapterSources: Set<String> = [
    "SentryCrashBridge.swift",
    "SentryCrashInstallationReporter.swift",
    "SentryCrashIntegration.swift",
    "SentryCrashSwift.swift",
    "SentryCrashV9Dependencies.swift",
    "SentryDefaultCrashReporter.swift"
]
private let v9OnlyTargets: Set<String> = [
    "SentryCrashV9",
    "SentryCrashV9Swift",
    "_SentryCrashV9Headers"
]

private func makeBaseManifestPackage(at destination: URL) throws -> URL {
    let package = destination.appendingPathComponent("package", isDirectory: true)
    try fileManager.createDirectory(at: package, withIntermediateDirectories: true)

    let skippedNames: Set<String> = [
        ".build",
        ".git",
        "Package.swift",
        "Package@swift-6.1.swift",
        "Package@swift-6.2.swift"
    ]

    for source in try fileManager.contentsOfDirectory(
        at: repositoryRoot,
        includingPropertiesForKeys: nil
    ) where !skippedNames.contains(source.lastPathComponent) {
        try fileManager.createSymbolicLink(
            at: package.appendingPathComponent(source.lastPathComponent),
            withDestinationURL: source
        )
    }

    try fileManager.copyItem(
        at: repositoryRoot.appendingPathComponent("Package.swift"),
        to: package.appendingPathComponent("Package.swift")
    )

    return package
}

private func packageDescription(for route: Route) throws -> PackageDescription {
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("sentry-v10-\(route.rawValue)-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let package = route == .baseManifest
        ? try makeBaseManifestPackage(at: temporaryDirectory)
        : repositoryRoot
    var arguments = [
        "swift",
        "package",
        "--package-path", package.path,
        "--scratch-path", temporaryDirectory.appendingPathComponent("build").path
    ]

    if route == .trait {
        arguments += ["--traits", "V10"]
    }
    arguments += ["describe", "--type", "json"]

    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = FileHandle.standardError
    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "SDK_V10")

    if route != .trait {
        environment["SDK_V10"] = "1"
    }
    process.environment = environment

    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "V10SwiftPMRouteVerifier",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "swift package describe failed for the \(route.rawValue) route"]
        )
    }

    return try JSONDecoder().decode(PackageDescription.self, from: data)
}

private func selectedContents(
    from description: PackageDescription,
    route: Route
) throws -> [String: TargetContents] {
    let targets = Dictionary(uniqueKeysWithValues: description.targets.map { ($0.name, $0) })
    guard let adapterTarget = targets["SentryCrashV9Swift"],
          adapterTarget.path.hasSuffix("Sources/SentryCrashV9Swift"),
          Set(adapterTarget.sources ?? []) == v9AdapterSources else {
        throw NSError(
            domain: "V10SwiftPMRouteVerifier",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "the \(route.rawValue) manifest does not isolate the expected V9 Swift adapters"]
        )
    }

    return try Dictionary(uniqueKeysWithValues: comparedTargets.map { name in
        guard let target = targets[name] else {
            throw NSError(
                domain: "V10SwiftPMRouteVerifier",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "the \(route.rawValue) route has no \(name) target"]
            )
        }

        return (
            name,
            TargetContents(
                sources: Set(target.sources ?? []),
                targetDependencies: Set(target.targetDependencies ?? []),
                productDependencies: Set(target.productDependencies ?? [])
            )
        )
    })
}

private func reportDifference(
    route: Route,
    target: String,
    kind: String,
    baseline: Set<String>,
    candidate: Set<String>
) {
    guard baseline != candidate else { return }

    print("error: \(route.rawValue) \(target) \(kind) differ from environment V10:")

    for value in candidate.subtracting(baseline).sorted() {
        print("  + \(value)")
    }

    for value in baseline.subtracting(candidate).sorted() {
        print("  - \(value)")
    }
}

private func verify(
    route: Route,
    target: String,
    expected: TargetContents,
    actual: TargetContents
) -> Bool {
    var succeeded = true
    let v9Sources = actual.sources.intersection(v9OnlySwiftSources)
    if !v9Sources.isEmpty {
        succeeded = false

        print("error: \(route.rawValue) \(target) schedules V9-only Swift sources:")

        for source in v9Sources.sorted() {
            print("  \(source)")
        }
    }

    let v9Dependencies = actual.targetDependencies.intersection(v9OnlyTargets)
    if !v9Dependencies.isEmpty {
        succeeded = false

        print("error: \(route.rawValue) \(target) selects V9-only targets:")

        for dependency in v9Dependencies.sorted() {
            print("  \(dependency)")
        }
    }

    if actual != expected {
        succeeded = false

        reportDifference(
            route: route,
            target: target,
            kind: "sources",
            baseline: expected.sources,
            candidate: actual.sources
        )

        reportDifference(
            route: route,
            target: target,
            kind: "target dependencies",
            baseline: expected.targetDependencies,
            candidate: actual.targetDependencies
        )

        reportDifference(
            route: route,
            target: target,
            kind: "product dependencies",
            baseline: expected.productDependencies,
            candidate: actual.productDependencies
        )
    }

    return succeeded
}

private func run() throws -> Bool {
    var routes: [Route: [String: TargetContents]] = [:]
    for route in Route.allCases {
        routes[route] = try selectedContents(from: packageDescription(for: route), route: route)
    }
    guard let baseline = routes[.environment] else { return false }

    var succeeded = true
    for route in Route.allCases {
        guard let contents = routes[route] else { continue }

        for target in comparedTargets {
            guard let expected = baseline[target], let actual = contents[target] else { continue }

            succeeded = verify(route: route, target: target, expected: expected, actual: actual)
                && succeeded
        }
    }

    return succeeded
}

do {
    guard try run() else { exit(1) }
    print("Verified equivalent SwiftPM environment, trait, and base-manifest V10 source graphs")
} catch {
    print("error: \(error.localizedDescription)")
    exit(1)
}
