#!/usr/bin/env swift

// V10 replaces the legacy SentryCrash recorder with KSCrash, but shared crash-reporting features
// and intentional compatibility must survive that migration. This verifier guards the separation
// so future changes do not quietly reintroduce the old backend or remove SDK-side code just
// because it still has a historical SentryCrash name. V9 continues to use the legacy recorder.

import Foundation

private let fileManager = FileManager.default
private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .standardizedFileURL
private var errors: [String] = []

private extension URL {
    func appending(_ path: String) -> URL {
        appendingPathComponent(path)
    }
}

private func text(_ path: String) throws -> String {
    try String(contentsOf: repositoryRoot.appending(path), encoding: .utf8)
}

private func lines(_ path: String) throws -> [String] {
    try text(path).components(separatedBy: .newlines)
}

private func report(_ message: String) {
    errors.append(message)
}

private func runProcess(_ executable: String, _ arguments: [String]) throws -> String {
    let output = Pipe()
    let process = Process()
    process.currentDirectoryURL = repositoryRoot
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let result = String(data: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "V10SentryCrashSourceContract",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: result.isEmpty ? "process failed" : result]
        )
    }
    return result
}

private func regularFileNames(in path: String) throws -> Set<String> {
    let directory = repositoryRoot.appending(path)
    return Set(try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey]
    ).compactMap { url in
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
              url.lastPathComponent != "module.modulemap" else { return nil }
        return url.lastPathComponent
    })
}

private func implementationFileNames(in path: String) throws -> Set<String> {
    let directory = repositoryRoot.appending(path)
    guard let enumerator = fileManager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey]
    ) else { return [] }
    let extensions: Set<String> = ["c", "cc", "cpp", "m", "mm"]
    var result: Set<String> = []
    for case let url as URL in enumerator where extensions.contains(url.pathExtension) {
        if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result.insert(url.lastPathComponent)
        }
    }
    return result
}

// This repository contract intentionally checks many independent resulting state invariants in one
// executable; keeping them together makes the verifier's policy much easier to read. Thus:
// swiftlint:disable cyclomatic_complexity function_body_length
private func phaseEntries(
    project: [String],
    marker: String,
    kind: String
) throws -> [String] {
    guard let start = project.firstIndex(where: { $0.contains(marker) }) else {
        report("missing Xcode phase \(marker)")
        return []
    }
    guard let end = project[(start + 1)...].firstIndex(where: { $0.hasPrefix("\t\t};") }) else {
        report("unterminated Xcode phase \(marker)")
        return []
    }
    let pattern = try NSRegularExpression(pattern: #"/\* (.+) in \#(kind) \*/"#)
    return project[start...end].compactMap { line in
        let range = NSRange(line.startIndex..., in: line)
        guard let match = pattern.firstMatch(in: line, range: range),
              let value = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[value])
    }
}

private func matches(_ pattern: String, _ value: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}

private func activeV10Imports(_ path: String) throws -> Set<String> {
    var active = true
    var stack: [(parent: Bool, branch: Bool?)] = []
    var imports: Set<String> = []
    let importPattern = try NSRegularExpression(pattern: #"^#\s*(?:include|import)\s*[<\"]([^>\"]+)[>\"]"#)

    for rawLine in try lines(path) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if matches(#"^#\s*if\s+!SDK_V10\s*$"#, line) {
            stack.append((active, false))
            active = false
        } else if matches(#"^#\s*if\s+SDK_V10\s*$"#, line) {
            stack.append((active, true))
        } else if matches(#"^#\s*else\b"#, line), let last = stack.last, let branch = last.branch {
            stack[stack.count - 1] = (last.parent, !branch)
            active = last.parent && !branch
        } else if matches(#"^#\s*endif\b"#, line), let last = stack.popLast() {
            active = last.parent
        } else if active {
            let range = NSRange(line.startIndex..., in: line)
            if let match = importPattern.firstMatch(in: line, range: range),
               let value = Range(match.range(at: 1), in: line) {
                imports.insert(URL(fileURLWithPath: String(line[value])).lastPathComponent)
            }
        }
    }
    return imports
}

private func run() throws {
    if CommandLine.arguments.count != 1 {
        print("Usage: \(CommandLine.arguments[0])")
        exit(1)
    }

    let project = try lines("Sentry.xcodeproj/project.pbxproj")
    let v9HeaderNames = try regularFileNames(in: "Sources/SentryCrashV9Headers/include")
    var legacySourceNames = try implementationFileNames(in: "Sources/SentryCrash")
    legacySourceNames.formUnion([
        "SentryCrashDefaultMachineContextWrapper.m",
        "SentryCrashReportSink.m",
        "SentryCrashScopeObserver.m"
    ])

    for name in v9HeaderNames.sorted() where fileManager.fileExists(
        atPath: repositoryRoot.appending("Sources/Sentry/include/\(name)").path
    ) {
        report("recorder header remains in neutral include path: \(name)")
    }

    let v10Sources = try phaseEntries(
        project: project,
        marker: "A9073C6F28FEA4B259D57E1C /* Sources */ = {",
        kind: "Sources"
    )
    for name in Set(v10Sources).intersection(legacySourceNames).sorted() {
        report("V10 Xcode source phase contains V9 implementation: \(name)")
    }

    let v10Headers = try phaseEntries(
        project: project,
        marker: "DB9A231CB1C05A5228D9C1B4 /* Headers */ = {",
        kind: "Headers"
    )
    for name in Set(v10Headers).intersection(v9HeaderNames).sorted() {
        report("V10 Xcode header phase contains recorder header: \(name)")
    }
    let allowedHistoricalHeaders: Set<String> = [
        "SentryCrashExceptionApplication.h",
        "SentryCrashReportConverter.h",
        "SentryCrashStackEntryMapper.h"
    ]
    for name in v10Headers.filter({ $0.hasPrefix("SentryCrash") }).sorted()
        where !allowedHistoricalHeaders.contains(name) {
        report("unreviewed historically named V10 Xcode header: \(name)")
    }

    for umbrella in [
        "Sources/Sentry/include/SentryPrivate.h",
        "SentryTestUtils/Headers/SentryTestUtils-ObjC-BridgingHeader.h",
        "Tests/SentryTests/SentryTests-Bridging-Header.h"
    ] {
        for name in try activeV10Imports(umbrella).intersection(v9HeaderNames).sorted() {
            report("\(umbrella) imports recorder header in its V10 branch: \(name)")
        }
    }

    let v9AdapterSources = try regularFileNames(in: "Sources/SentryCrashV9Swift")
        .filter { $0.hasSuffix(".swift") }
        .sorted()
        .map { try text("Sources/SentryCrashV9Swift/\($0)") }
        .joined(separator: "\n")
    let registrationPattern = #"@usableFromInline\s+@_cdecl\("sentrycrash_v9_registerSwiftBackend"\)\s+"#
        + #"(?:internal\s+)?func\s+sentrycrash_v9_registerSwiftBackend\s*\("#
    if matches(#"\bpublic\s+func\s+sentrycrash_v9_registerSwiftBackend\b"#, v9AdapterSources) {
        report("The V9 C registration boundary must not become public SDK API")
    } else if !matches(registrationPattern, v9AdapterSources) {
        report("The internal V9 C registration boundary must remain ABI-visible for cross-module linking")
    }

    let manifestNames = ["Package.swift", "Package@swift-6.1.swift", "Package@swift-6.2.swift"]
    for manifestName in manifestNames {
        let manifest = try text(manifestName)
        if manifest.contains(#".headerSearchPath("SentryCrash"#) {
            report("\(manifestName) exposes a Sources/SentryCrash header-search path")
        }
        if !manifest.contains(#""SentryCrash","#) || !manifest.contains(#"name: "SentryCrashV9""#) {
            report("\(manifestName) does not isolate the V9 recorder target")
        }
        if !manifest.contains(#"path: "Sources/SentryCrashV9Headers""#) {
            report("\(manifestName) does not use the V9-only recorder header target")
        }
        if !manifest.contains(#"publicHeadersPath: "include""#) {
            report("\(manifestName) has no explicit private public-header path")
        }
    }
    for manifestName in ["Package@swift-6.1.swift", "Package@swift-6.2.swift"] {
        let manifest = try text(manifestName)
        if manifest.contains(#".when(traits: ["V9"])"#) || manifest.contains(#".default(enabledTraits: ["V9"])"#) {
            report("\(manifestName) reintroduces mandatory V9 selection")
        }
    }
    let olderManifest = try text("Package@swift-6.1.swift")
    if olderManifest.contains(#".when(traits: ["V10"])"#) {
        report("The older manifest must use environment-only V10 development selection")
    }
    if !(try text("Package@swift-6.2.swift")).contains(#".when(traits: ["V10"])"#) {
        report("The modern manifest is missing its development V10 opt-in")
    }

    for requiredPath in [
        "Sources/Sentry/Public/SentryCrashExceptionApplication.h",
        "Sources/Sentry/include/SentryCrashReportConverter.h",
        "Sources/Sentry/include/SentryCrashStackEntryMapper.h",
        "Sources/Sentry/SentryScopeSyncC.c",
        "Sources/Sentry/include/SentryScopeSyncC.h"
    ] where !fileManager.fileExists(atPath: repositoryRoot.appending(requiredPath).path) {
        report("retained compatibility source/header is missing: \(requiredPath)")
    }

    let v10TestConfig = try text("Tests/Configuration/SentryTestsV10.xcconfig")
    let v10TestPlan = try text("Plans/SentryV10_Base.xctestplan")
    for sharedTest in [
        "SentryCrashReportConverterTests.m",
        "SentryCrashStackEntryMapperTests.swift",
        "SentryDebugImageProviderTests.swift",
        "SentryStacktraceBuilderTests.swift"
    ] where v10TestConfig.contains(sharedTest) {
        report("V10 source selection excludes shared test: \(sharedTest)")
    }
    for sharedSuite in [
        "SentryCrashReportConverterTests",
        "SentryCrashStackEntryMapperTests",
        "SentryKSCrashNSExceptionTests"
    ] where v10TestPlan.contains("\"\(sharedSuite)") {
        report("V10 test plan skips shared suite: \(sharedSuite)")
    }

    let compatibilityTest = try text(
        "Tests/SentryTests/Integrations/KSCrash/SentryKSCrashLegacyRecorderExclusionTests.swift"
    )
    if !compatibilityTest.contains(#"NSClassFromString("SentryCrashExceptionApplication")"#) {
        report("V10 tests lack positive SentryCrashExceptionApplication runtime coverage")
    }

    let workflow = try text(".github/workflows/build-v10.yml")
    for requiredJobOrTarget in [
        "package-v10:",
        "build-xcframework-v10-dynamic",
        "build-xcframework-v10-static",
        "build-xcframework-sentryobjc-v10"
    ] where !workflow.contains(requiredJobOrTarget) {
        report("V10 workflow is missing packaging coverage: \(requiredJobOrTarget)")
    }
    if workflow.components(separatedBy: "package-v10").count - 1 < 2 {
        report("The required V10 build check does not depend on the packaging matrix")
    }

    if !(try text("Makefile")).contains("verify-v10-sentrycrash-sentryobjc.sh") {
        report("The V10 SentryObjC package target does not run its recorder audit")
    }

    do {
        let callbackOutput = try runProcess(
            "/usr/bin/grep",
            ["-R", "-nE", #"(^|[^[:alnum:]_])ksbic_registerForImageAdded[[:space:]]*\("#, "Sources"]
        )
        if !callbackOutput.isEmpty {
            report("SDK source must not take KSCrash's single image-added callback slot")
        }
    } catch let error as NSError where error.code == 1 {
        // grep returns 1 when there are no matches.
    }

    for requiredAudit in ["test-v10-empty-objects.sh", "--build-log v10-environment.log",
                          "--build-log v10-trait.log", "--build-log v10-base-manifest.log"] where !workflow.contains(requiredAudit) {
        report("SwiftPM V10 builds must run the object checker with their build logs; missing workflow command: \(requiredAudit)")
    }
}
// swiftlint:enable cyclomatic_complexity function_body_length

do {
    try run()
} catch {
    report(error.localizedDescription)
}

if !errors.isEmpty {
    for error in errors {
        print("error: \(error)")
    }
    print("error: \(errors.count) V10 SentryCrash source-contract violation(s) found")
    exit(1)
}
print("Verified V10 separation source ownership, header delivery, compatibility and audit coverage")
