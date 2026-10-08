#!/usr/bin/env swift

// Test the verifier with small, temporary repositories and build plans.
// Compile the helper once and run the shell wrapper for each case, without building the SDK
// or changing the real repository.

import Foundation

private let files = FileManager.default
private let scripts = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
private typealias Object = [String: Any]
private struct TestFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestFailure(message: message) }
}

private func write(_ data: Data, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

private func write(_ text: String, to path: String) throws {
    try write(Data(text.utf8), to: path)
}

private func writeJSON(_ value: Any, to path: String) throws {
    try write(JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), to: path)
}

private func process(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

private final class Fixture {
    let repository: String
    let build: String
    let configuration: String
    let safeSource: String
    let badSource: String
    let recorderSource: String
    let header: String
    let allowed = "C.SentrySwift-arm64-apple-macosx-debug.module"
    let adapter = "C.SentryCrashV9Swift-arm64-apple-macosx-debug.module"
    var commands: [String: Object] = [:]
    var targets: [String: [String]] = [:]
    var records: [String: Object] = [:]
    var scans: [String: [String]] = [:]
    var writers: [String: Object] = [:]
    var extraDescription: Object = [:]

    init(root: URL, helper: URL, native: Bool) throws {
        repository = root.appendingPathComponent("repository with spaces").path
        build = root.appendingPathComponent("build with spaces").path
        configuration = build + "/arm64-apple-macosx/debug"
        safeSource = repository + "/Sources/Swift/Allowed.swift"
        badSource = repository + "/Sources/SentryCrashV9Swift/SentryCrashIntegration.swift"
        recorderSource = repository + "/Sources/SentryCrash/Recording/SentryCrashC.c"
        header = repository + "/Sources/SentryCrash/Recording/SentryCrashC.h"
        try files.createDirectory(atPath: build, withIntermediateDirectories: true)
        for path in [safeSource, badSource, recorderSource, header] { try write("fixture\n", to: path) }
        try write("fixture\n", to: repository + "/Sources/SentryCrashV9Headers/include/Header.h")
        for name in ["verify-v10-sentrycrash-objects.sh", "ci-utils.sh"] {
            try write(Data(contentsOf: scripts.appendingPathComponent(name)), to: repository + "/scripts/" + name)
        }
        let destination = repository + "/scripts/verify-v10-spm-build-plan.swift"
        try files.copyItem(atPath: helper.path, toPath: destination)
        if native {
            try addModule("SentrySwift", source: safeSource, completed: true)
            try addModule("SentryCrashV9Swift", source: badSource, completed: false)
            targets["main"] = ["<SentrySwift-arm64-apple-macosx-debug.module>", "<SentryCrashV9Swift-arm64-apple-macosx-debug.module>"]
            try savePlan()
            try saveDescription()
        }
    }

    func modulePath(_ module: String, _ name: String) -> String {
        configuration + "/\(module).build/\(name)"
    }

    private func addModule(_ module: String, source: String, completed: Bool) throws {
        let name = "\(module)-arm64-apple-macosx-debug.module"
        let objectPath = modulePath(module, URL(fileURLWithPath: source).lastPathComponent + ".o")
        let list = modulePath(module, "sources")
        let map = modulePath(module, "output-file-map.json")
        commands[list] = ["tool": "write-auxiliary-file", "inputs": ["<sources-file-list>", source], "outputs": [list]]
        commands["C." + name] = [
            "tool": "shell", "inputs": [source, list], "outputs": [objectPath],
            "args": ["swiftc", "-output-file-map", map, "@" + list]
        ]
        commands["<" + name + ">"] = ["tool": "phony", "inputs": [objectPath], "outputs": ["<" + name + ">"]]
        targets[name] = ["<" + name + ">"]
        records["C." + name] = [
            "moduleName": module, "sources": [source], "objects": [objectPath],
            "fileList": list, "outputFileMapPath": map
        ]
        scans[module] = [source]
        writers[list] = [
            "outputFilePath": list,
            "inputs": [["kind": "virtual", "name": "<sources-file-list>"], ["kind": "file", "name": source]]
        ]
        try writeJSON([source: ["object": objectPath]], to: map)
        if completed {
            try write("fixture object\n", to: objectPath)
            try write(source + "\n", to: list)
        }
    }

    func savePlan() throws {
        // JSON is valid YAML, which lets us create test plans using Foundation.
        // The workflow's SDK builds supply real SwiftPM YAML plans for the actual audit.
        try writeJSON(["commands": commands, "targets": targets, "default": "main"], to: build + "/debug.yaml")
    }

    func saveDescription() throws {
        let description: Object = [
            "swiftCommands": records, "swiftTargetScanArgs": scans, "writeCommands": writers,
            "pluginDescriptions": [Any](), "swiftFrontendCommands": Object()
        ]
        try writeJSON(description.merging(extraDescription) { _, new in new }, to: configuration + "/description.json")
    }

    func changeCommand(_ name: String, _ change: (inout Object) -> Void) throws {
        guard var command = commands[name] else { throw TestFailure(message: "Missing fixture command") }
        change(&command)
        commands[name] = command
        try savePlan()
    }
}

private final class Tests {
    private let temporary = files.temporaryDirectory.appendingPathComponent("v10-plan-tests-\(UUID().uuidString)")
    private let helper: URL
    private var count = 0

    init() throws {
        try require(CommandLine.arguments.count == 1, "Usage: \(CommandLine.arguments[0])")
        try files.createDirectory(at: temporary, withIntermediateDirectories: true)
        helper = temporary.appendingPathComponent("verify-plan")
        let compilation = try process("/usr/bin/env", ["swiftc", scripts.appendingPathComponent("verify-v10-spm-build-plan.swift").path, "-o", helper.path])
        try require(compilation.status == 0, "Helper compilation failed:\n\(compilation.output)")
    }

    deinit { try? files.removeItem(at: temporary) }

    private func test(
        _ name: String,
        expected: Int32 = 1,
        diagnostic: String = "",
        native: Bool = true,
        roots: [String] = ["SentrySwift"],
        change: (Fixture) throws -> Void = { _ in }
    ) throws {
        let fixture = try Fixture(root: temporary.appendingPathComponent(name), helper: helper, native: native)
        try change(fixture)
        let arguments = [fixture.repository + "/scripts/verify-v10-sentrycrash-objects.sh", "--build-path", fixture.build]
            + roots.flatMap { ["--spm-target", $0] }
        let result = try process("/bin/bash", arguments)
        try require(result.status == expected && (diagnostic.isEmpty || result.output.contains(diagnostic)),
                    "FAIL \(name): expected \(expected) / \(diagnostic), got \(result.status):\n\(result.output)")
        count += 1
        print("PASS \(name) (exit \(result.status))")
    }

    func testRoots() throws {
    try test("inactive-plan", expected: 0)
    try test("plugin-tools-plan", expected: 0) {
        try files.copyItem(atPath: $0.build + "/debug.yaml", toPath: $0.build + "/plugin-tools.yaml")
        try files.copyItem(atPath: $0.configuration + "/description.json", toPath: $0.configuration + "/plugin-tools-description.json")
    }
    try test("missing-selection", diagnostic: "explicit --spm-target", roots: [])
    try test("missing-root", diagnostic: "Missing or ambiguous", roots: ["Missing"])
    try test("adapter-root", diagnostic: "schedules a V9", roots: ["SentryCrashV9Swift"])
    try test("empty-root", diagnostic: "Empty requested root") {
        $0.targets["SentrySwift-arm64-apple-macosx-debug.module"] = []
        try $0.savePlan()
    }
    try test("ambiguous-root", diagnostic: "Missing or ambiguous") {
        $0.targets["SentrySwift-x86_64-apple-macosx-debug.module"] = $0.targets["SentrySwift-arm64-apple-macosx-debug.module"]
        try $0.savePlan()
    }
    }

    func testGraph() throws {
    try test("recorder-in-allowed-target", diagnostic: "schedules a V9") { fixture in
        try fixture.changeCommand(fixture.allowed) { $0["inputs"] = [fixture.safeSource, fixture.recorderSource] }
    }
    try test("adapter-in-allowed-arguments", diagnostic: "schedules a V9") { fixture in
        try fixture.changeCommand(fixture.allowed) { $0["args"] = ["swiftc", fixture.badSource] }
    }
    try test("source-list-drift", diagnostic: "schedules a V9") {
        try write($0.safeSource + "\n" + $0.badSource, to: $0.modulePath("SentrySwift", "sources"))
    }
    try test("unresolved-edge", diagnostic: "Unresolved native plan input") { fixture in
        try fixture.changeCommand(fixture.allowed) { $0["inputs"] = [fixture.safeSource, "<unresolved>"] }
    }
    try test("cycle", diagnostic: "Cycle in native plan") { fixture in
        try fixture.changeCommand(fixture.allowed) { $0["inputs"] = ["<SentrySwift-arm64-apple-macosx-debug.module>"] }
    }
    try test("ambiguous-producer", diagnostic: "Ambiguous producer") {
        $0.commands["duplicate"] = $0.commands[$0.allowed]
        try $0.savePlan()
    }
    try test("unsupported-tool", diagnostic: "Unsupported reachable native tool") { fixture in
        try fixture.changeCommand(fixture.allowed) { $0["tool"] = "unknown-tool" }
    }
    try test("missing-completed-output", diagnostic: "Missing completed native output") {
        try files.removeItem(atPath: $0.modulePath("SentrySwift", "Allowed.swift.o"))
    }
    }

    func testMetadata() throws {
    try test("malformed-plan", diagnostic: "Cannot check the native SwiftPM build") {
        try write("commands: [unterminated", to: $0.build + "/debug.yaml")
    }
    try test("missing-description", diagnostic: "Missing or ambiguous native description") {
        try files.removeItem(atPath: $0.configuration + "/description.json")
    }
    try test("unsupported-plugins", diagnostic: "Unsupported native plugin/frontend") {
        $0.extraDescription["pluginDescriptions"] = ["uninspected plugin"]
        try $0.saveDescription()
    }
    try test("description-source-drift", diagnostic: "Swift description disagrees") {
        $0.records[$0.allowed, default: [:]]["sources"] = [$0.recorderSource]
        try $0.saveDescription()
    }
    try test("inactive-output-map-drift", diagnostic: "Output map sources disagree") {
        try writeJSON([$0.recorderSource: ["object": "unexpected.o"]], to: $0.modulePath("SentryCrashV9Swift", "output-file-map.json"))
    }
    try test("selected-output-map-drift", diagnostic: "Output map objects disagree") {
        try writeJSON([$0.safeSource: ["object": "unexpected.o"]], to: $0.modulePath("SentrySwift", "output-file-map.json"))
    }
    try test("unknown-description-source", diagnostic: "schedules a V9") {
        $0.extraDescription["unclassified"] = $0.recorderSource
        try $0.saveDescription()
    }
    try test("unknown-json-not-exempt", diagnostic: "build metadata schedules") {
        try writeJSON(["source": $0.recorderSource], to: $0.build + "/unknown.json")
    }
    }

    func testOutputs() throws {
    try test("emitted-object", diagnostic: "emitted an object reserved") {
        try write("fixture object", to: $0.build + "/SentryCrashC.c.o")
    }
    try test("header-dependency", diagnostic: "resolves a V9 recorder header") {
        try write("Allowed.o: " + $0.header, to: $0.build + "/Allowed.d")
    }
    try test("source-dependency", diagnostic: "build metadata schedules") {
        try write("Allowed.o: " + $0.recorderSource, to: $0.build + "/Allowed.d")
    }
    }

    func testNonNative() throws {
    try test("non-native-baseline", expected: 0, native: false, roots: [])
    try test("non-native-compatibility-object", expected: 0, native: false) {
        try write("fixture object", to: $0.build + "/SentryCrashReportConverter.o")
    }
    try test("non-native-file-list", diagnostic: "build metadata schedules", native: false) {
        try write($0.recorderSource, to: $0.build + "/Sentry.SwiftFileList")
    }
    try test("non-native-object", diagnostic: "emitted an object reserved", native: false) {
        try write("fixture object", to: $0.build + "/SentryCrashIntegration.swift.o")
    }
    try test("non-native-header", diagnostic: "resolves a V9 recorder header", native: false) {
        try write($0.header, to: $0.build + "/Allowed.scan")
    }
    }

    func run() throws {
        try testRoots()
        try testGraph()
        try testMetadata()
        try testOutputs()
        try testNonNative()
        print("\(count) V10 build-plan/object audit regressions passed")
    }
}

do {
    try Tests().run()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
