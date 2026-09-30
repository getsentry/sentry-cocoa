#!/usr/bin/env swift

// Xcode also discovers packages through navigator folders. When XcodeGen adds both a folder
// and an explicit V10 package reference, that second discovery enables default V9 traits.
// Remove only those duplicate folders; keep the explicit package request and its traits.

import Foundation

private typealias Object = [String: Any]
private struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(message: message) }
}

private func decode(_ text: String) throws -> Object {
    guard let project = try PropertyListSerialization.propertyList(
        from: Data(text.utf8), options: [], format: nil
    ) as? Object else {
        throw Failure(message: "Expected a project dictionary")
    }

    return project
}

private func directory(_ path: String, relativeTo root: URL) throws -> String {
    try require(!path.isEmpty && !path.contains("$"), "Unsupported package directory: \(path)")
    return URL(fileURLWithPath: path, relativeTo: root)
        .standardizedFileURL.resolvingSymlinksInPath().path
}

private func v10Directories(objects: [String: Object], project: Object, root: URL) throws -> Set<String> {
    guard let references = project["packageReferences"] as? [String] else {
        throw Failure(message: "Missing project package references")
    }

    var packageDirectories = Set<String>()

    for identifier in references {
        guard let reference = objects[identifier] else {
            throw Failure(message: "Missing package reference \(identifier)")
        }

        guard reference["isa"] as? String == "XCLocalSwiftPackageReference" else { continue }
        if let traits = reference["traits"] {
            try require(traits is [String], "Malformed traits on \(identifier)")
        }

        guard (reference["traits"] as? [String])?.contains("V10") == true else { continue }

        guard let path = reference["relativePath"] as? String else {
            throw Failure(message: "Missing local package path on \(identifier)")
        }

        packageDirectories.insert(try directory(path, relativeTo: root))
    }

    return packageDirectories
}

private func duplicateFolders(objects: [String: Object], directories: Set<String>, root: URL) throws -> Set<String> {
    var removed = Set<String>()

    for (identifier, object) in objects {
        guard object["isa"] as? String == "PBXFileReference",
              object["lastKnownFileType"] as? String == "folder"
                || object["explicitFileType"] as? String == "folder",
              object["sourceTree"] as? String == "SOURCE_ROOT",
              let path = object["path"] as? String else { continue }

        if directories.contains(try directory(path, relativeTo: root)) {
            removed.insert(identifier)
        }
    }

    return removed
}

// A duplicate folder may be a navigator child only, never a build input or another
// object's property. Check all references before removing anything from the project.
private func checkReferences(_ value: Any, removed: Set<String>) throws {
    if let string = value as? String {
        try require(!removed.contains(string), "Package folder is referenced outside navigator children")
    } else if let array = value as? [Any] {
        for element in array { try checkReferences(element, removed: removed) }
    } else if let dictionary = value as? Object {
        for element in dictionary.values { try checkReferences(element, removed: removed) }
    }
}

private func removingObjects(_ original: Object, objects: [String: Object], removed: Set<String>) throws -> Object {
    var expected = original
    var objects = objects

    for (identifier, var object) in objects where !removed.contains(identifier) {
        if object["isa"] as? String == "PBXGroup", let children = object["children"] as? [String] {
            object["children"] = children.filter { !removed.contains($0) }
        }
        try checkReferences(object, removed: removed)
        objects[identifier] = object
    }

    for identifier in removed { objects.removeValue(forKey: identifier) }
    expected["objects"] = objects
    for (key, value) in expected where key != "objects" { try checkReferences(value, removed: removed) }

    return expected
}

// Keep XcodeGen's formatting and comments. The caller checks the reparsed dictionary
// before accepting these text replacements.
private func removingText(_ original: String, removed: Set<String>) throws -> String {
    var updated = original

    for identifier in removed.sorted() {
        try require(identifier.range(of: "^[A-Fa-f0-9]{24}$", options: .regularExpression) != nil,
                    "Unsupported object identifier \(identifier)")
        let comment = "(?: /\\*[^\\n]*?\\*/)?"
        let definition = try NSRegularExpression(
            pattern: "(?ms)^[\\t ]*" + identifier + comment + "[\\t ]*=[\\t ]*\\{.*?\\};[\\t ]*\\r?\\n?"
        )

        let range = NSRange(updated.startIndex..., in: updated)
        try require(definition.numberOfMatches(in: updated, range: range) == 1,
                    "Expected one folder definition for \(identifier)")
        updated = definition.stringByReplacingMatches(in: updated, range: range, withTemplate: "")
        let child = try NSRegularExpression(
            pattern: "(?m)^[\\t ]*" + identifier + comment + "[\\t ]*,[\\t ]*\\r?\\n?"
        )
        updated = child.stringByReplacingMatches(
            in: updated, range: NSRange(updated.startIndex..., in: updated), withTemplate: ""
        )
    }

    return updated
}

private func removeFolders(from projectURL: URL) throws {
    let file = projectURL.appendingPathComponent("project.pbxproj")
    let root = projectURL.deletingLastPathComponent()
    let original = try String(contentsOf: file, encoding: .utf8)
    let decoded = try decode(original)
    guard let objects = decoded["objects"] as? [String: Object],
          let rootID = decoded["rootObject"] as? String,
          let project = objects[rootID], project["isa"] as? String == "PBXProject" else {
        throw Failure(message: "Missing project objects")
    }

    let directories = try v10Directories(objects: objects, project: project, root: root)
    if directories.isEmpty {
        print("No explicit V10 local packages in \(projectURL.lastPathComponent)")
        return
    }

    let removed = try duplicateFolders(objects: objects, directories: directories, root: root)
    if removed.isEmpty {
        print("No duplicate V10 package folders in \(projectURL.lastPathComponent)")
        return
    }

    let expected = try removingObjects(decoded, objects: objects, removed: removed)
    let updated = try removingText(original, removed: removed)
    let actual = try decode(updated)
    try require(NSDictionary(dictionary: actual).isEqual(to: expected),
                "Project text changes differ from the permitted folder removal")
    try Data(updated.utf8).write(to: file, options: .atomic)
    print("Removed \(removed.count) duplicate V10 package folder(s) from \(projectURL.lastPathComponent)")
}

do {
    try require(CommandLine.arguments.count == 2, "Usage: remove-v10-package-folder-references.swift <project.xcodeproj>")
    let project = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    try require(project.pathExtension == "xcodeproj", "Expected an .xcodeproj directory")
    try removeFolders(from: project)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
