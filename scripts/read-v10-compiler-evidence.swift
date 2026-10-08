#!/usr/bin/env swift

// Decode observed compiler/relocatable-link commands into source/output records.
// This is not an inactive build-plan projection. The caller validates ownership,
// completed outputs, flags and object contents; no command from the log is executed.
import Foundation

private struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct Record: Encodable {
    let source: String
    let output: String
    let arguments: [String]
    let inputs: [String]
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(message: message) }
}

// Split compiler arguments using single/double quotes and backslash escaping.
// Backslashes are literal inside single quotes. Elsewhere, including inside double
// quotes, a backslash escapes the next character. This is not a full shell parser.
private func words(_ text: some StringProtocol) throws -> [String] {
    var result: [String] = []
    var word = ""
    var quote: Character?
    var escaped = false
    var started = false

    for character in text {
        if escaped {
            word.append(character)
            escaped = false
        } else if character == "\\" && quote != "'" {
            escaped = true
            started = true
        } else if let current = quote {
            if character == current { quote = nil } else { word.append(character) }
        } else if character == "'" || character == "\"" {
            quote = character
            started = true
        } else if character.isWhitespace {
            if started { result.append(word); word = ""; started = false }
        } else {
            word.append(character)
            started = true
        }
    }

    try require(quote == nil && !escaped, "Unterminated compiler argument quoting")

    if started { result.append(word) }

    return result
}

private func expand(_ arguments: [String], visiting: Set<String> = []) throws -> [String] {
    var result: [String] = []

    for argument in arguments {
        // These prefixes are macOS loader paths, not compiler response files.
        let loaderPath = ["@loader_path", "@executable_path", "@rpath"].contains {
            argument == $0 || argument.hasPrefix($0 + "/")
        }
        if argument.hasPrefix("@") && !loaderPath {
            let response = URL(fileURLWithPath: String(argument.dropFirst())).resolvingSymlinksInPath()

            try require(FileManager.default.fileExists(atPath: response.path) && !visiting.contains(response.path),
                        "Missing/cyclic response file: \(response.path)")

            result += try expand(words(String(contentsOf: response, encoding: .utf8)), visiting: visiting.union([response.path]))
        } else {
            result.append(argument)
        }
    }

    return result
}

private func option(_ arguments: [String], _ name: String) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }

    try require(index + 1 < arguments.count, "Missing compiler argument: \(name)")

    return arguments[index + 1]
}

private func compileRecords(_ arguments: [String]) throws -> [Record] {
    let extensions: Set<String> = ["c", "cc", "cpp", "m", "mm", "swift"]
    var sources = arguments.filter { $0.hasPrefix("/") && extensions.contains(URL(fileURLWithPath: $0).pathExtension) }

    if let map = try option(arguments, "-output-file-map") {
        let mapping = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: URL(fileURLWithPath: map)))

        try require(Set(mapping.keys).subtracting([""]) == Set(sources), "Output map/source-list disagreement: \(map)")

        return try sources.map { source in
            guard let outputs = mapping[source],
                  let object = outputs["object"] else {
                throw Failure(message: "Missing source object in output map: \(map)")
            }
            return Record(source: source, output: object, arguments: arguments, inputs: [])
        }
    }

    let outputs = arguments.indices.dropLast().filter { arguments[$0] == "-o" }.map { arguments[$0 + 1] }
    let primaries = arguments.indices.dropLast().filter { arguments[$0] == "-primary-file" }.map { arguments[$0 + 1] }
    if !primaries.isEmpty { sources = primaries }

    if outputs.isEmpty {
        return []
    }
    try require(sources.count == outputs.count, "Ambiguous source/output association")

    return zip(sources, outputs).map { Record(source: $0, output: $1, arguments: arguments, inputs: []) }
}

private func aggregateRecord(_ arguments: [String]) throws -> Record {
    guard let list = try option(arguments, "-filelist"), let output = try option(arguments, "-o") else {
        throw Failure(message: "Relocatable link requires an output and input file list")
    }

    // A -nostdlib relocatable link only combines accounted objects, not external libraries
    // or synthesized sections. Do not exempt an aggregate merely because its name is familiar.
    try require(arguments.contains("-nostdlib") && !arguments.contains(where: {
        $0.contains("sectcreate") || $0.hasSuffix(".a") || $0.hasSuffix(".dylib")
    }), "Unsupported relocatable link inputs/options")

    // ld file lists contain one literal path per line, not shell-quoted arguments.
    let inputs = try String(contentsOfFile: list, encoding: .utf8).split(separator: "\n").map(String.init)
    try require(!inputs.isEmpty && inputs.allSatisfy { $0.hasPrefix("/") && $0.hasSuffix(".o") }, "Invalid aggregate object list")

    return Record(source: "", output: output, arguments: arguments, inputs: inputs)
}

private func read(_ log: String) throws -> [Record] {
    let compilers = #/(?:^|\s)((?:'|")?\/[^\n]*?\/(?:clang\+\+|clang|swiftc|swift-frontend)(?:'|")?)\s/#
    var result: [Record] = []

    for line in log.split(separator: "\n") {
        guard let hit = line.firstMatch(of: compilers) else { continue }

        let raw = try words(line[hit.1.startIndex...])
        let arguments = try expand(raw)

        if arguments.contains("-package-description-version") { continue }

        if arguments.contains("-c") || arguments.contains("-emit-object") {
            result += try compileRecords(arguments)
        } else if arguments.contains("-r") {
            result.append(try aggregateRecord(arguments))
        }
    }

    return result
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    try require(arguments.count == 2 && ["--build-log", "-l"].contains(arguments[0]),
                "Usage: read-v10-compiler-evidence.swift --build-log|-l PATH")

    let records = try read(String(contentsOfFile: arguments[1], encoding: .utf8))
    let encoder = JSONEncoder()

    encoder.outputFormatting = [.sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(records))
} catch {
    fputs("Cannot read compiler commands from the build log: \(error.localizedDescription)\n", stderr)
    exit(1)
}
