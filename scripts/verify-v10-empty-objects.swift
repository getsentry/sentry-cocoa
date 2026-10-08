#!/usr/bin/env swift

// swiftlint:disable file_length

// Use a fresh build's full verbose log to identify compiled files and inspect their objects.
// Legacy files may compile before V9 branches off, but must emit no recorder implementation.
// This checker supports development and downstream SDK testing before the branch split.
// Retire it when V9 and V10 no longer share a branch. Check packaged SDKs separately too.

import Foundation
private let files = FileManager.default
private struct AuditFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw AuditFailure(message: message) }
}

private func tool(_ arguments: [String]) throws -> String {
    let pipe = Pipe()

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let output = String(decoding: data, as: UTF8.self)
    try require(process.terminationStatus == 0, "Tool failed: \(arguments.joined(separator: " ")):\n\(output)")

    return output
}

private func path(_ value: String) -> URL {
    URL(fileURLWithPath: value).standardizedFileURL.resolvingSymlinksInPath()
}

private func isFile(_ value: String) throws -> Bool {
    do {
        // Foundation can report a dangling symlink as non-regular without throwing.
        try require(files.fileExists(atPath: value), "File is missing or inaccessible")
        let metadata = try path(value).resourceValues(forKeys: [.isRegularFileKey])
        guard let regular = metadata.isRegularFile else {
            throw AuditFailure(message: "File type is unavailable")
        }

        return regular
    } catch {
        throw AuditFailure(message: "Cannot read file metadata: \(value): \(error.localizedDescription)")
    }
}

private func descendants(_ root: URL) throws -> [URL] {
    var traversalErrors: [String] = []
    guard let enumerator = files.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        errorHandler: { url, error in
            traversalErrors.append("\(url.path): \(error.localizedDescription)")
            return true
        }
    ) else {
        throw AuditFailure(message: "Cannot enumerate \(root.path)")
    }

    var result: [URL] = []
    for entry in enumerator {
        guard let url = entry as? URL else {
            throw AuditFailure(message: "Unexpected directory entry while enumerating \(root.path): \(entry)")
        }

        if try isFile(url.path) { result.append(url) }
    }

    // An incomplete search cannot certify that all relevant files were inspected.
    try require(traversalErrors.isEmpty,
                "Cannot enumerate \(root.path):\n\(traversalErrors.joined(separator: "\n"))")

    return result
}

private func option(_ arguments: [String], _ name: String) throws -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }

    try require(index + 1 < arguments.count, "Missing compiler argument: \(name)")

    return arguments[index + 1]
}

private let extensions: Set<String> = ["c", "cc", "cpp", "m", "mm", "swift"]
private let extraSources: Set<String> = [
    "Sources/Sentry/SentryCrashDefaultMachineContextWrapper.m",
    "Sources/Sentry/SentryCrashReportSink.m",
    "Sources/Sentry/SentryCrashScopeObserver.m",
    "Sources/Swift/Core/Integrations/SentryCrashV9Backend.swift"
]
private let legacyTargets: Set<String> = ["SentryCrashV9.build", "SentryCrashV9ObjC.build", "SentryCrashV9Swift.build"]

private func sourceKey(_ source: String) -> String {
    let parts = URL(fileURLWithPath: source).pathComponents

    guard let index = parts.lastIndex(of: "Sources") else { return "" }

    return parts[index...].joined(separator: "/")
}

private func legacy(_ key: String) -> Bool {
    key.hasPrefix("Sources/SentryCrash/") || key.hasPrefix("Sources/SentryCrashV9Swift/") || extraSources.contains(key)
}

private struct Section: Equatable {
    let segment: String
    let name: String
    let address: UInt64
    let size: Int
    let flags: UInt32
    let data: Data
    let relocations: Int
}

private func sections(_ object: URL, allowEmpty: Bool = false) throws -> [Section] {
    let raw = try Data(contentsOf: object)
    let loads = try tool(["xcrun", "otool", "-l", object.path])

    let commandPattern = #/^Load command \d+\n.*?(?=^Load command \d+\n|\z)/#
        .anchorsMatchLineEndings().dotMatchesNewlines()
    let segmentPattern = #/^[ \t]*cmd LC_SEGMENT_64[ \t]*$/#.anchorsMatchLineEndings()
    let segments = loads.matches(of: commandPattern).map(\.output).filter {
        $0.firstMatch(of: segmentPattern) != nil
    }
    try require(!segments.isEmpty, "No 64-bit Mach-O segment commands found (32-bit objects are not supported): \(object.path)")

    let countPattern = #/^[ \t]*nsects (\d+)[ \t]*$/#.anchorsMatchLineEndings()
    let pattern = #/Section\s+sectname (\S+)\s+segname (\S+)\s+addr (\S+)\s+size (\S+)\s+offset (\d+)\s+align [^\n]+\s+reloff (\d+)\s+nreloc (\d+)\s+flags (0x[0-9a-fA-F]+)/#
    let result = try segments.enumerated().flatMap { index, segment -> [Section] in
        let counts = segment.matches(of: countPattern)
        guard counts.count == 1, let expected = Int(counts[0].1) else {
            throw AuditFailure(message: "Missing/invalid segment section count: \(object.path): segment \(index)")
        }
        let records = segment.matches(of: pattern)

        // Check each command separately: missing sections in one segment must not be
        // hidden by extra matches in another. Count all sections before excluding DWARF.
        try require(records.count == expected,
                    "Section inventory mismatch: \(object.path): segment \(index) reports \(expected), parsed \(records.count)")
        return try records.map { record -> Section in
            guard let address = UInt64(record.3.dropFirst(2), radix: 16),
                  let size = Int(record.4.dropFirst(2), radix: 16), let offset = Int(record.5),
                  let relocations = Int(record.7), let flags = UInt32(record.8.dropFirst(2), radix: 16) else {
                throw AuditFailure(message: "Invalid section metadata: \(object.path)")
            }

            let zeroFill = [UInt32(1), 12, 18].contains(flags & 0xff)

            try require(zeroFill || (offset <= raw.count && size <= raw.count - offset), "Invalid section bounds: \(object.path)")

            return Section(
                segment: String(record.2),
                name: String(record.1),
                address: address,
                size: size,
                flags: flags,
                data: zeroFill ? Data() : raw.subdata(in: offset..<(offset + size)),
                relocations: relocations
            )
        }
    }

    try require(allowEmpty || !result.isEmpty, "Missing object sections: \(object.path)")

    return result
}

private func symbols(_ object: URL) throws -> [String] {
    let output = try tool(["xcrun", "nm", "-m", object.path])

    if output.trimmingCharacters(in: .whitespacesAndNewlines) == object.path + ": no symbols" { return [] }

    return output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
}

private struct Signature: Equatable {
    let sections: [Section]
    let symbols: [String]
    let relocations: [String]
    let linkerOptions: [String]
}

private func signature(_ object: URL, allowEmptySections: Bool = false) throws -> Signature {
    let relocationText = try tool(["xcrun", "otool", "-rv", object.path])
    let relocationPattern = #/(?s)Relocation information.*?(?=Relocation information|\z)/#
    let blocks = relocationText.matches(of: relocationPattern)
        .map { String($0.output) }.filter { !$0.contains("(__DWARF,") }
    let loads = try tool(["xcrun", "otool", "-l", object.path])
    let linkerOptionPattern = #/(?s)cmd LC_LINKER_OPTION.*?(?=Load command|\z)/#
    let options = loads.matches(of: linkerOptionPattern).map { String($0.output) }

    return try Signature(sections: sections(object, allowEmpty: allowEmptySections).filter { $0.segment != "__DWARF" },
                         symbols: symbols(object), relocations: blocks, linkerOptions: options)
}

private func headerReference(_ object: URL, arguments: [String], source: String) throws {
    // SentryDefines emits SDK-owned constants before this wrapper's recorder guard.
    // Recompile ONLY that header with the observed compiler/flags, then compare all
    // runtime sections, local/global symbols and relocations. Do not ignore symbols just because their names look familiar.
    let temporary = files.temporaryDirectory.appendingPathComponent("sentry-header-only-\(UUID().uuidString)")
    try files.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? files.removeItem(at: temporary) }

    let stub = temporary.appendingPathComponent("empty.m")
    let reference = temporary.appendingPathComponent("empty.o")
    try Data("#import \"SentryDefines.h\"\n".utf8).write(to: stub)

    var rewritten: [String] = []
    var skip = false

    for argument in arguments {
        if skip { skip = false; continue }
        if ["-o", "-MF", "-MT", "-index-store-path", "-serialize-diagnostics"].contains(argument) {
            skip = true
        } else if !["-MD", "-MMD"].contains(argument) {
            rewritten.append(argument == source ? stub.path : argument)
        }
    }

    _ = try tool(rewritten + ["-o", reference.path])
    let expected = try signature(reference)
    let implementation = expected.sections.contains { section in
        section.size > 0 && (["__text", "__stubs", "__stub_helper", "__mod_init_func", "__mod_term_func"].contains(section.name)
                             || (section.name.hasPrefix("__objc_") && section.name != "__objc_imageinfo"))
    }

    try require(!implementation, "Header-only reference emits implementation: \(source)")
    try require(signature(object) == expected,
                "Legacy implementation differs from SDK header-only reference: \(object.path)")
}

private let swiftLibraries: Set<String> = [
    "swiftCompatibility56", "swiftCompatibilityConcurrency", "swiftCompatibilityDynamicReplacements", "swiftCompatibilityPacks",
    "swiftARKit", "swiftAVFoundation", "swiftCoreAudio", "swiftCoreFoundation", "swiftCoreImage", "swiftCoreLocation", "swiftCoreMIDI", "swiftCoreMedia",
    "swiftDispatch", "swiftFoundation", "swiftIOKit", "swiftMapKit", "swiftMetal", "swiftOSLog", "swiftSceneKit",
    "swiftObjectiveC", "swiftQuartzCore", "swiftSpatial", "swiftUIKit", "swiftUniformTypeIdentifiers", "swiftWatchKit", "swiftXPC", "swift_Builtin_float", "swiftos", "swiftsimd"
]

private func inspectEmpty(_ object: URL, arguments: [String], source: String) throws {
    if sourceKey(source) == "Sources/Sentry/SentryCrashDefaultMachineContextWrapper.m" {
        try headerReference(object, arguments: arguments, source: source)
        return
    }

    if !source.hasSuffix(".swift") {
        let loads = try tool(["xcrun", "otool", "-l", object.path])
        try require(!loads.contains("cmd LC_LINKER_OPTION"), "Unexpected legacy implementation autolink: \(object.path)")
    }

    let syms = try symbols(object)
    let module = try option(arguments, "-module-name") ?? ""
    let forceDefinitions = try validateSymbols(syms, module: module, source: source, object: object)

    for section in try sections(object) where section.size > 0 && section.segment != "__DWARF" {
        switch (section.segment, section.name) {
        case ("__DATA", "__objc_imageinfo"):
            try require(section.data.count == 8 && section.data.prefix(4) == Data(repeating: 0, count: 4) && section.relocations == 0,
                        "Unexpected implementation metadata: \(object.path)")
        case ("__LLVM", "__swift_modhash"):
            try require(section.data.count == 16 && section.relocations == 0, "Unexpected implementation metadata: \(object.path)")
        case ("__TEXT", "__const"):
            try require(section.data == Data([3, 0]) && section.relocations == 0 && syms.contains { $0.hasSuffix("___swift_reflection_version") },
                        "Unexpected legacy implementation data: \(object.path)")
        case ("__DATA", "__const"):
            try verifyForceLoads(section, definitions: forceDefinitions, module: module, object: object)
        default:
            throw AuditFailure(message: "Unexpected legacy implementation section: \(object.path): \(section.segment),\(section.name)")
        }
    }
}

private func validateSymbols(_ syms: [String], module: String, source: String, object: URL) throws -> [String] {
    var forceDefinitions: [String] = []

    for line in syms {
        let name = String(line.split(separator: " ").last ?? "")

        if name.firstMatch(of: #/^(ltmp\d+|l_llvm\.swift_module_hash)$/#) != nil { continue }

        if name == "___swift_reflection_version" {
            try require(line.contains("(__TEXT,__const)"), "Unexpected implementation symbol: \(line)")
            continue
        }

        if name.hasPrefix("__swift_FORCE_LOAD_$_") {
            let suffix = String(name.dropFirst("__swift_FORCE_LOAD_$_".count))
            let library = suffix.components(separatedBy: "_$_")[0]

            try require(source.hasSuffix(".swift") && swiftLibraries.contains(library)
                        && (line.contains("(undefined) weak external")
                            || (line.contains("(__DATA,__const) weak private external") && suffix == library + "_$_" + module)),
                        "Unexpected implementation symbol: \(line)")

            if !line.contains("(undefined)") { forceDefinitions.append(line) }

            continue
        }

        throw AuditFailure(message: "Unexpected legacy implementation symbol: \(object.path): \(line)")
    }

    return forceDefinitions
}

private func verifyForceLoads(_ section: Section, definitions: [String], module: String, object: URL) throws {
    try require(section.data.count == 8 * definitions.count && section.data == Data(repeating: 0, count: section.data.count)
                && section.relocations == definitions.count, "Unexpected legacy implementation data: \(object.path)")

    var expected: [UInt64: String] = [:]

    for line in definitions {
        let parts = line.split(separator: " ")

        guard let first = parts.first, let address = UInt64(first, radix: 16), address >= section.address, let name = parts.last else {
            throw AuditFailure(message: "Invalid force-load metadata: \(object.path)")
        }

        try require(expected[address - section.address] == nil, "Ambiguous compiler metadata: \(object.path)")

        expected[address - section.address] = String(name).replacingOccurrences(of: "_$_" + module, with: "")
    }

    let relocationText = try tool(["xcrun", "otool", "-rv", object.path])
    let blockPattern = #/(?s)Relocation information \(__DATA,__const\).*?(?=Relocation information|\z)/#
    let blocks = relocationText.matches(of: blockPattern)
    try require(blocks.count == 1, "Missing compiler metadata relocations: \(object.path)")

    var actual: [UInt64: String] = [:]

    let relocationPattern = #/^([0-9a-fA-F]+)\s+False\s+.*?True\s+UNSIGND\s+False\s+(\S+)$/#
        .anchorsMatchLineEndings()
    for record in blocks[0].output.matches(of: relocationPattern) {
        guard let address = UInt64(record.1, radix: 16) else { throw AuditFailure(message: "Invalid metadata relocation") }
        try require(actual[address] == nil, "Ambiguous metadata relocation")
        actual[address] = String(record.2)
    }

    try require(actual == expected && Set(expected.keys) == Set(stride(from: UInt64(0), to: UInt64(section.data.count), by: 8)),
                "Unexpected implementation relocation: \(object.path)")
}

private func audit(build: URL, log: URL, sourceRoot: URL) throws {
    let inventory = Set(try descendants(sourceRoot.appendingPathComponent("Sources")).filter {
        extensions.contains($0.pathExtension) && legacy(sourceKey($0.path))
    }.map { sourceKey($0.path) })
    try require(!inventory.isEmpty, "Missing legacy source inventory")

    let text = try String(contentsOf: log, encoding: .utf8)
    let completedBuildPattern = #/Build(?: of target: '[^'\n]+')? complete!|\*\* (BUILD|ARCHIVE) SUCCEEDED \*\*/#
    try require(text.firstMatch(of: completedBuildPattern) != nil,
                "The log does not show a successfully completed build; use the full verbose log from a fresh build")
    let failedBuildPattern = #/\*\* (BUILD|ARCHIVE) FAILED \*\*|^error:/#
        .anchorsMatchLineEndings()
    try require(text.firstMatch(of: failedBuildPattern) == nil, "Failed/incomplete build: the log contains a build failure or error")

    let observed = try observedOutputs(log, build: build, inventory: inventory)
    try verifyAggregates(observed)

    let audited = try auditOutputs(build, inventory: inventory, observed: observed)
    print("Verified \(audited) implementation-free legacy objects; \(observed.count) completed compiler outputs accounted")
}

private struct CompilerRecord: Decodable {
    let source: String
    let output: String
    let arguments: [String]
    let inputs: [String]
}

private typealias ObservedOutputs = [String: CompilerRecord]

private func observedOutputs(_ log: URL, build: URL, inventory: Set<String>) throws -> ObservedOutputs {
    let reader = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("read-v10-compiler-evidence.swift")
    let data = try tool(["swift", reader.path, "--build-log", log.path])
    let records = try JSONDecoder().decode([CompilerRecord].self, from: Data(data.utf8))

    var observed: ObservedOutputs = [:]

    for record in records where record.output.hasSuffix(".o") {
        let object = path(record.output)
        try require(object.path.hasPrefix(build.path + "/"), "Compiler output outside --build-path: \(object.path)")
        try require(files.fileExists(atPath: object.path), "Missing completed output: \(object.path)")
        try require(isFile(object.path), "Completed output is not a regular file: \(object.path)")

        let key = sourceKey(record.source)
        try require(!legacy(key) || inventory.contains(key), "Unknown legacy source: \(record.source)")

        if let previous = observed[object.path] {
            try require(previous.source == record.source && previous.inputs == record.inputs, "Ambiguous output producer: \(object.path)")
        }
        observed[object.path] = record

        if legacy(key) { try verifyFlags(record.arguments, source: record.source) }
    }

    try require(observed.values.contains { !$0.source.isEmpty }, "No compiler commands producing object files were found in the build log")

    return observed
}

private func verifyAggregates(_ observed: ObservedOutputs) throws {
    var accounted = Set(observed.filter { !$0.value.source.isEmpty }.keys)
    var pending = observed.filter { $0.value.source.isEmpty }

    while !pending.isEmpty {
        let ready = pending.filter { Set($0.value.inputs.map { path($0).path }).isSubset(of: accounted) }

        try require(!ready.isEmpty, "Unaccounted/cyclic aggregate inputs")

        for (output, record) in ready {
            try aggregateReference(path(output), record: record)
            accounted.insert(output)
            pending.removeValue(forKey: output)
        }
    }
}

private func aggregateReference(_ object: URL, record: CompilerRecord) throws {
    let temporary = files.temporaryDirectory.appendingPathComponent("sentry-aggregate-only-\(UUID().uuidString)")
    try files.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? files.removeItem(at: temporary) }
    let reference = temporary.appendingPathComponent("reference.o")

    let arguments = record.arguments.map { argument -> String in
        if argument == record.output { return reference.path }

        if argument.hasSuffix("_lto.o") || argument.hasSuffix("_dependency_info.dat") {
            return temporary.appendingPathComponent(URL(fileURLWithPath: argument).lastPathComponent).path
        }

        return argument
    }

    _ = try tool(arguments)
    let matches: Bool
    if URL(fileURLWithPath: record.arguments[0]).lastPathComponent == "libtool" {
        // -D removes archive timestamps; exact bytes certify membership and contents,
        // including nested archives, without exempting historically familiar names.
        matches = try Data(contentsOf: object) == Data(contentsOf: reference)
    } else {
        matches = try signature(object, allowEmptySections: true) == signature(reference, allowEmptySections: true)
    }
    try require(matches, "Aggregate implementation differs from accounted input objects: \(object.path)")
}

private func auditOutputs(_ build: URL, inventory: Set<String>, observed: ObservedOutputs) throws -> Int {
    let names = Set(inventory.flatMap { key in
        [URL(fileURLWithPath: key).deletingPathExtension().lastPathComponent + ".o", URL(fileURLWithPath: key).lastPathComponent + ".o"]
    })

    let expected = Set(observed.values.filter { legacy(sourceKey($0.source)) }.map { path($0.output).path })
    var audited: Set<String> = []

    for entry in try descendants(build) where entry.pathExtension == "o" {
        let object = path(entry.path)
        let isLegacy = names.contains(entry.lastPathComponent) || !legacyTargets.isDisjoint(with: entry.pathComponents)
        if isLegacy { try require(observed[object.path] != nil, "Unaccounted legacy object: \(object.path)") }

        if let record = observed[object.path] {
            if legacy(sourceKey(record.source)) {
                try inspectEmpty(object, arguments: record.arguments, source: record.source)
                audited.insert(object.path)
            } else {
                try require(!isLegacy, "Ambiguous legacy object ownership: \(object.path): \(record.source)")
            }
        } else if Set(["checkouts", "artifacts", "repositories"]).isDisjoint(with: entry.pathComponents.dropFirst(build.pathComponents.count)) {
            throw AuditFailure(message: "Unaccounted compiler object: \(object.path)")
        }
    }

    let missing = expected.subtracting(audited).sorted()
    let unexpected = audited.subtracting(expected).sorted()
    try require(expected == audited,
                "Legacy object coverage mismatch. Not inspected: \(missing). Unexpectedly inspected: \(unexpected)")

    return audited.count
}

// Recognize direct -D/-U and Swift -Xcc forms, skipping operands of common options.
// This deliberately does not model arbitrary compiler options or macros supplied by
// headers. Object inspection separately checks what the compiler actually emitted.
private func definitionArguments(_ arguments: [String]) throws -> (direct: [String], clang: [String]) {
    let operands: Set<String> = [
        "-MT", "-MQ", "-MF", "-o", "-x", "-I", "-F", "-include", "-imacros", "-isystem",
        "-isysroot", "-sdk", "-target", "-module-name", "-output-file-map",
        "-Xfrontend", "-Xclang", "-Xpreprocessor", "-Xlinker", "-Xllvm", "-mllvm"
    ]
    var direct: [String] = []
    var clang: [String] = []
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        index += 1

        if argument == "--" { break }

        if argument == "-Xcc" || argument == "-D" || argument == "-U" || operands.contains(argument) {
            try require(index < arguments.count, "Missing compiler argument: \(argument)")

            if argument == "-Xcc" {
                clang.append(arguments[index])
            } else if argument == "-D" || argument == "-U" {
                direct.append(argument + arguments[index])
            }

            index += 1
        } else if argument.hasPrefix("-D") || argument.hasPrefix("-U") {
            direct.append(argument)
        }
    }

    return (direct, clang)
}

private func conflictsWithV10(_ flag: String, swift: Bool) -> Bool {
    let payload = String(flag.dropFirst(2))
    let macro = payload.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""

    guard macro == "SDK_V10" || macro.hasPrefix("SDK_V10(") else { return false }

    return flag.hasPrefix("-U") || (swift ? payload != "SDK_V10" : !["SDK_V10", "SDK_V10=1"].contains(payload))
}

private func verifyFlags(_ arguments: [String], source: String) throws {
    // Xcode dependency-scan records can prefix the compiler with an output path and --.
    // Start at the actual compiler, so that separator is not treated as its end of options.
    let compilers: Set<String> = ["clang", "clang++", "swiftc", "swift-frontend"]
    guard let compiler = arguments.firstIndex(where: { compilers.contains(URL(fileURLWithPath: $0).lastPathComponent) }) else {
        throw AuditFailure(message: "Missing compiler executable: \(source)")
    }

    let swift = source.hasSuffix(".swift")
    let flags = try definitionArguments(Array(arguments.dropFirst(compiler + 1)))
    let imported = swift ? try definitionArguments(flags.clang).direct : []

    // An importer definition cannot substitute for Swift's conditional-compilation flag.
    // Its absence is allowed: SDK configuration headers can supply the Clang macro.
    try require(!flags.direct.contains { conflictsWithV10($0, swift: swift) }
                && !imported.contains { conflictsWithV10($0, swift: false) }, "Conflicting V10 flag: \(source)")

    let accepted = swift ? ["-DSDK_V10"] : ["-DSDK_V10", "-DSDK_V10=1"]
    try require(flags.direct.contains { accepted.contains($0) }, "Missing selected V10 flag: \(source)")
}

private func run() throws {
    let aliases = ["-b": "--build-path", "-l": "--build-log", "-s": "--source-root"]
    let arguments = Array(CommandLine.arguments.dropFirst())
    try require(arguments.count.isMultiple(of: 2), "Usage: verify-v10-empty-objects.swift --build-path PATH --build-log PATH [--source-root PATH]")

    var options: [String: String] = [:]

    for index in stride(from: 0, to: arguments.count, by: 2) {
        let name = aliases[arguments[index]] ?? arguments[index]
        try require(aliases.values.contains(name) && options[name] == nil && !arguments[index + 1].isEmpty, "Invalid argument: \(name)")
        options[name] = arguments[index + 1]
    }

    guard let build = options["--build-path"], let log = options["--build-log"] else {
        throw AuditFailure(message: "--build-path and --build-log are required")
    }

    let sourceRoot = options["--source-root"].map(path) ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    try audit(build: path(build), log: path(log), sourceRoot: sourceRoot)
}

do {
    try run()
} catch {
    fputs("V10 build-output check failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
