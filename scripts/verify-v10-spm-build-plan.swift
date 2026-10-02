#!/usr/bin/env swift

// SwiftPM's native build plan lists commands for every target, including targets we didn't build.
// Check the commands needed by the requested targets, then tell the shell script which metadata
// files we have checked. The shell script still checks compiled object files and header dependencies.

import Foundation

private let files = FileManager.default
private typealias Object = [String: Any]
private struct VerificationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw VerificationFailure(message: message) }
}

private func object(_ value: Any?) throws -> Object {
    guard let result = value as? Object else {
        throw VerificationFailure(message: "Expected a metadata object")
    }
    return result
}

private func strings(_ value: Any?) throws -> [String] {
    guard let result = value as? [String] else {
        throw VerificationFailure(message: "Expected metadata paths/arguments")
    }
    return result
}

private func string(_ value: Any?) throws -> String {
    guard let result = value as? String else {
        throw VerificationFailure(message: "Expected a metadata path/name")
    }
    return result
}

private func json(_ data: Data) throws -> Object {
    try object(JSONSerialization.jsonObject(with: data))
}

private func readJSON(_ path: String) throws -> Object {
    try json(Data(contentsOf: URL(fileURLWithPath: path)))
}

private func isFile(_ path: String) -> Bool {
    (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
}

private func yaml(_ path: String) throws -> Object {
    // Foundation doesn't read YAML. Use yq, which is in Brewfile and installed on the CI runner.
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["yq", "-o=json", ".", path]
    process.standardOutput = output
    process.standardError = FileHandle.standardError

    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    try require(process.terminationStatus == 0, "Could not decode native YAML with yq: \(path)")
    return try json(data)
}

private struct Command {
    let raw: Object
    let tool: String
    let inputs: [String]
    let outputs: [String]
    let arguments: [String]

    init(_ raw: Object) throws {
        self.raw = raw
        tool = try string(raw["tool"])
        inputs = try strings(raw["inputs"])
        outputs = try strings(raw["outputs"])
        arguments = try strings(raw["args"] ?? [String]())
    }
}

private final class BuildPlan {
    let path: String
    let patterns: [String]
    private(set) var commands: [String: Command] = [:]
    private(set) var reached: Set<String> = []
    private var producers: [String: String] = [:]
    private var visiting: Set<String> = []

    init(path: String, requested: [String], patterns: [String]) throws {
        self.path = path
        self.patterns = patterns

        let data = try yaml(path)

        for (name, value) in try object(data["commands"]) {
            let command = try Command(object(value))
            commands[name] = command

            for output in command.outputs {
                try require(producers[output] == nil, "Ambiguous producer: \(output)")
                producers[output] = name
            }
        }

        try select(requested, targets: object(data["targets"]))
        try require(reached.contains { commands[$0]?.tool == "clang" || $0.hasPrefix("C.") },
                    "Requested roots contain no compiler commands")

        print("Verified native SwiftPM roots \(requested.joined(separator: ", ")): "
              + "\(reached.count) reachable commands in \(URL(fileURLWithPath: path).lastPathComponent)")
    }

    private func select(_ requested: [String], targets: Object) throws {
        for target in requested {
            let matches = targets.keys.filter { $0.hasPrefix(target + "-") && $0.hasSuffix(".module") }
            guard matches.count == 1, let root = matches.first else {
                throw VerificationFailure(message: "Missing or ambiguous requested SwiftPM target: \(target)")
            }

            let nodes = try strings(targets[root])
            try require(!nodes.isEmpty, "Empty requested root: \(target)")
            for node in nodes {
                guard let producer = producers[node], let command = commands[producer] else {
                    throw VerificationFailure(message: "Unresolved native root: \(node)")
                }

                try require(!command.inputs.isEmpty, "Empty requested root: \(target)")
                try visit(node)
            }
        }
    }

    func rejectSources(_ value: Any, context: String) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])
        let text = String(decoding: data, as: UTF8.self)
        let matches = patterns.filter { text.contains($0) }
        try require(matches.isEmpty, "V10 requested build schedules a V9 recorder or adapter: "
                    + "\(context): \(matches.joined(separator: ", "))")
    }

    private func visit(_ node: String) throws {
        guard let name = producers[node], let command = commands[name] else {
            try require(node.hasPrefix("/") && files.fileExists(atPath: node), "Unresolved native plan input: \(node)")
            return
        }

        try require(!visiting.contains(name), "Cycle in native plan: \(name)")
        if reached.contains(name) { return }
        
        let tools: Set<String> = ["clang", "shell", "phony", "write-auxiliary-file", "copy-tool",
                                  "package-structure-tool", "test-entry-point-tool"]

        try require(tools.contains(command.tool), "Unsupported reachable native tool: \(command.tool)")
        try rejectSources(command.raw, context: name)
        visiting.insert(name)

        for input in command.inputs {
            // LLBuild uses these special names when writing a source list or Swift version file.
            // They aren't file paths or build commands to follow.
            if command.tool == "write-auxiliary-file", ["<sources-file-list>", "<swift-get-version>"].contains(input) {
                continue
            }

            try visit(input)
        }

        for argument in command.arguments where argument.hasPrefix("@") {
            let path = String(argument.dropFirst())
            try require(isFile(path), "Missing native response/source list: \(path)")
            try rejectSources(String(contentsOfFile: path, encoding: .utf8), context: path)
        }

        for output in command.outputs where output.hasSuffix(".o") || output.hasSuffix(".swiftmodule") {
            try require(isFile(output), "Missing completed native output: \(output)")
        }

        visiting.remove(name)
        reached.insert(name)
    }
}

private func inputNames(_ record: Object) throws -> [String] {
    guard let inputs = record["inputs"] as? [Object] else {
        throw VerificationFailure(message: "Invalid description inputs")
    }
    return try inputs.map {
        let kind = try string($0["kind"])
        try require(["file", "virtual"].contains(kind), "Unsupported description input")
        return try string($0["name"])
    }
}

private func validateMap(_ record: Object, command: Command, buildPath: String) throws -> String {
    let path = try string(record["outputFileMapPath"])
    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    try require(resolved.hasPrefix(buildPath + "/") && command.arguments.contains(path),
                "Unassociated native output map: \(path)")

    let sources = try strings(record["sources"])
    let mapping = try readJSON(path)
    try require(Set(mapping.keys).subtracting([""]) == Set(sources), "Output map sources disagree with native plan: \(path)")

    let objects = try sources.map { try string(object(mapping[$0])["object"]) }
    try require(Set(objects) == Set(strings(record["objects"])), "Output map objects disagree with native plan: \(path)")

    return path
}

private struct SwiftSelection {
    let records: Object
    let modules: Set<String>
    let allModules: Set<String>
    let maps: Set<String>
}

private func selectedSwiftCommands(_ data: Object, plan: BuildPlan, buildPath: String) throws -> SwiftSelection {
    var selected: Object = [:]
    var modules: Set<String> = []
    var allModules: Set<String> = []
    var maps: Set<String> = []

    for (name, value) in try object(data["swiftCommands"]) {
        guard let command = plan.commands[name] else {
            throw VerificationFailure(message: "Description has an unplanned Swift command: \(name)")
        }

        let record = try object(value)
        let sources = try strings(record["sources"])
        let objects = try strings(record["objects"])
        try require(Set(sources).isSubset(of: Set(command.inputs))
                    && Set(objects).isSubset(of: Set(command.outputs))
                    && command.inputs.contains(string(record["fileList"])),
                    "Swift description disagrees with native plan: \(name)")

        let module = try string(record["moduleName"])
        try require(allModules.insert(module).inserted, "Ambiguous described Swift module: \(module)")

        let map = try validateMap(record, command: command, buildPath: buildPath)
        maps.insert(map)
        if plan.reached.contains(name) {
            selected[name] = record
            modules.insert(module)
            try plan.rejectSources(readJSON(map), context: map)
        }
    }

    return SwiftSelection(records: selected, modules: modules, allModules: allModules, maps: maps)
}

private func selectedWrites(_ data: Object, plan: BuildPlan) throws -> Object {
    var selected: Object = [:]

    for (name, value) in try object(data["writeCommands"]) {
        let record = try object(value)
        guard let command = plan.commands[name] else {
            throw VerificationFailure(message: "Description has an unplanned write command: \(name)")
        }
        try require(string(record["outputFilePath"]) == name && inputNames(record) == command.inputs,
                    "Write description disagrees with native plan: \(name)")

        if plan.reached.contains(name) { selected[name] = record }
    }

    return selected
}

private func validateDescription(_ path: String, plan: BuildPlan, buildPath: String) throws -> Set<String> {
    let data = try readJSON(path)
    guard let plugins = data["pluginDescriptions"] as? [Any], plugins.isEmpty,
          try object(data["swiftFrontendCommands"]).isEmpty else {
        throw VerificationFailure(message: "Unsupported native plugin/frontend description: \(path)")
    }

    let swift = try selectedSwiftCommands(data, plan: plan, buildPath: buildPath)
    let scans = try object(data["swiftTargetScanArgs"])
    try require(Set(scans.keys).isSubset(of: swift.allModules), "Scan arguments have an unplanned module: \(path)")

    var projected = data
    projected["swiftCommands"] = swift.records
    projected["swiftTargetScanArgs"] = try scans.filter { swift.modules.contains($0.key) }.mapValues { try strings($0) }
    projected["writeCommands"] = try selectedWrites(data, plan: plan)

    // Check the remaining fields for V9 source paths too; don't skip fields we don't recognize.
    try plan.rejectSources(projected, context: path)

    return swift.maps.union([path])
}

private func arguments() throws -> [String: [String]] {
    let aliases = ["-b": "--build-path", "-s": "--source-patterns", "-t": "--spm-target",
                   "-m": "--metadata-paths", "-r": "--remaining-metadata-paths"]
    let known = Set(aliases.values)
    let input = Array(CommandLine.arguments.dropFirst())
    try require(input.count.isMultiple(of: 2), "Arguments require named options and values")

    var result: [String: [String]] = [:]

    for index in stride(from: 0, to: input.count, by: 2) {
        let key = aliases[input[index]] ?? input[index]

        try require(known.contains(key) && !input[index + 1].isEmpty, "Unknown/empty argument: \(key)")
        try require(key == "--spm-target" || result[key] == nil, "Duplicate argument: \(key)")

        result[key, default: []].append(input[index + 1])
    }

    for key in known.subtracting(["--spm-target"]) {
        try require(result[key]?.count == 1, "Missing argument: \(key)")
    }

    return result
}

private func descriptions(in root: URL, configuration: String) throws -> [URL] {
    try files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).map {
        $0.appendingPathComponent(configuration).appendingPathComponent("description.json")
    }.filter { isFile($0.path) }
}

private func coveredMetadata(root: URL, requested: [String], patterns: [String]) throws -> Set<String> {
    let configurations = ["debug", "release"].filter { isFile(root.appendingPathComponent("\($0).yaml").path) }
    try require(!configurations.isEmpty && !requested.isEmpty,
                "Native SwiftPM requires a build plan and explicit --spm-target selections")

    let pluginPath = root.appendingPathComponent("plugin-tools.yaml").path
    let pluginPlan = isFile(pluginPath) ? try BuildPlan(path: pluginPath, requested: requested, patterns: patterns) : nil
    var covered: Set<String> = []

    for configuration in configurations {
        let path = root.appendingPathComponent("\(configuration).yaml").path
        let plan = try BuildPlan(path: path, requested: requested, patterns: patterns)
        let candidates = try descriptions(in: root, configuration: configuration)

        try require(candidates.count == 1, "Missing or ambiguous native description for \(configuration)")
        guard let description = candidates.first else { continue }

        covered.formUnion(try validateDescription(description.path, plan: plan, buildPath: root.path))
        covered.insert(path)

        let plugin = description.deletingLastPathComponent().appendingPathComponent("plugin-tools-description.json").path
        if let pluginPlan = pluginPlan {
            try require(isFile(plugin), "Missing native plugin-tools description")

            covered.formUnion(try validateDescription(plugin, plan: pluginPlan, buildPath: root.path))
            covered.insert(pluginPath)
        } else {
            try require(!files.fileExists(atPath: plugin), "Plugin description has no native plan")
        }
    }

    return covered
}

private func run() throws {
    let options = try arguments()
    func path(_ name: String) throws -> String {
        guard let value = options[name]?.first else { throw VerificationFailure(message: "Missing \(name)") }
        return value
    }
    let root = URL(fileURLWithPath: try path("--build-path")).resolvingSymlinksInPath()
    let patterns = try String(contentsOfFile: path("--source-patterns"), encoding: .utf8)
        .split(separator: "\n").map(String.init)

    try require(!patterns.isEmpty, "Missing forbidden-source patterns")

    // Foundation can call the same directory /var or /private/var.
    // Resolve the paths on both sides before comparing them.
    let covered = Set(try coveredMetadata(root: root, requested: options["--spm-target"] ?? [], patterns: patterns)
        .map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })
    let metadata = try Data(contentsOf: URL(fileURLWithPath: path("--metadata-paths")))
    var remaining = Data()

    for entry in metadata.split(separator: 0) {
        guard let name = String(data: Data(entry), encoding: .utf8) else {
            throw VerificationFailure(message: "Metadata path is not UTF-8")
        }

        if !covered.contains(URL(fileURLWithPath: name).resolvingSymlinksInPath().path) {
            remaining.append(contentsOf: entry)
            remaining.append(0)
        }
    }

    try remaining.write(to: URL(fileURLWithPath: path("--remaining-metadata-paths")))
}

do {
    try run()
} catch {
    fputs("Invalid V10 native SwiftPM evidence: \(error.localizedDescription)\n", stderr)
    exit(1)
}
