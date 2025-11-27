import Foundation
import Regex
import SwiftShell

protocol ErrorHandling: Error {
    var message: String { get }
}

enum FileError: Error, ErrorHandling {
    case fileNotFound(String)
    case unknownFile(String)
    
    var message: String {
        switch self {
        case .fileNotFound(let file):
            return "File not found: \(file)"
        case .unknownFile(let file):
            return "Unknown file: \(file)"
        }
    }
}

enum VersionError: Error, ErrorHandling {
    case versionNotFound(String)
    case versionNotFoundInCarthage(String, String)
    case versionMismatch(String, String)
    
    var message: String {
        switch self {
        case .versionNotFound(let file):
            return "No version found for \(file)"
        case .versionMismatch(let file, let versionFound):
            return "Unexpected version \(versionFound) found for file \(file)"
        case .versionNotFoundInCarthage(let file, let version):
            return "No version \(version) found in \(file) Carthage JSON file"
        }
    }
}

let fromVersionFile = "./Sentry.podspec"

let files = [
    "./Sentry.podspec",
    "./Package.swift",
    "./SentryPrivate.podspec",
    "./SentrySwiftUI.podspec",
    "./Sources/Sentry/SentryMeta.m",
    "./Tests/HybridSDKTest/HybridPod.podspec"
]

// Files that only accept the format x.x.x in order to release an app using the framework.
// This will enable publishing apps with SDK beta version.
let restrictFiles = [
    "./Sources/Configuration/SDK.xcconfig",
    "./Sources/Configuration/Versioning.xcconfig",
    "./Sources/Configuration/SentrySwiftUI.xcconfig"
]

let carthageFiles = [
    "./Sentry-Dynamic-WithARM64e.json",
    "./Sentry-Dynamic.json",
    "./Sentry-WithoutUIKitOrAppKit-WithARM64e.json",
    "./Sentry-WithoutUIKitOrAppKit.json",
    "./Sentry.json",
    "./SentrySwiftUI.json"
]

let args = CommandLine.arguments

let semver: StaticString = "([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+)?"
let regex = Regex(semver)
if regex.firstMatch(in: args[2]) == nil {
    exit(errormessage: "version number must fit x.x.x format" )
}

if args[1] == "--verify" {
    let expectedVersion = args[2]
    try verifyVersionInFiles(expectedVersion)
} else if args[1] == "--update" {
    try updateVersionInFiles()
}

func updateVersionInFiles() throws {
    let fromVersionFileHandler = try open(fromVersionFile)
    let fromFileContent: String = fromVersionFileHandler.read()

    if let match = Regex(semver, options: [.dotMatchesLineSeparators]).firstMatch(in: fromFileContent) {
        var fromVersion = match.matchedString
        var toVersion = args[2]

        for file in files {
            try updateVersion(file, fromVersion, toVersion)
        }

        for file in carthageFiles {
            try createNewCarthageVersion(file, toVersion)
        }
        
        fromVersion = extractVersionOnly(fromVersion)
        toVersion = extractVersionOnly(toVersion)
        
        for file in restrictFiles {
            try updateVersion(file, fromVersion, toVersion)
        }
    }
    print("Successfuly updated version numbers")
}

func updateVersion(_ file: String, _ fromVersion: String, _ toVersion: String) throws {
    let readFile = try open(file)
    let contents: String = readFile.read()
    let newContents = contents.replacingOccurrences(of: fromVersion, with: toVersion)
    let overwriteFile = try! open(forWriting: file, overwrite: true)
    overwriteFile.write(newContents)
    overwriteFile.close()
}

func createNewCarthageVersion(_ file: String, _ toVersion: String) throws {
    let readFile = try open(file)
    let contents: String = readFile.read()
    
    // Parse the JSON as [String: String]
    guard let jsonData = contents.data(using: .utf8) else {
        throw FileError.unknownFile("Could not convert file contents to data")
    }
    
    var versionDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] ?? [:]
    
    // Extract the filename to construct the URL
    let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".json", with: "")
    let newURL = "https://github.com/getsentry/sentry-cocoa/releases/download/\(toVersion)/\(fileName).xcframework.zip"
    
    // Add the new version
    versionDict[toVersion] = newURL
    
    // Sort by version keys
    let sortedKeys = versionDict.keys.sorted { compareVersions($0, $1) }
    let sortedDict = sortedKeys.reduce(into: [:]) { result, key in
        result[key] = versionDict[key]
    }
    
    // Use JSONEncoder with pretty printing and without escaping slashes
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let outputData = try encoder.encode(sortedDict)
    guard let jsonString = String(data: outputData, encoding: .utf8) else {
        throw FileError.unknownFile("Could not convert JSON data to string")
    }
    
    // Write back to file
    let overwriteFile = try! open(forWriting: file, overwrite: true)
    overwriteFile.write(jsonString)
    overwriteFile.close()
}

func compareVersions(_ v1: String, _ v2: String) -> Bool {
    let parts1 = v1.split(separator: ".").compactMap { Int($0) }
    let parts2 = v2.split(separator: ".").compactMap { Int($0) }
    
    let maxLength = max(parts1.count, parts2.count)
    
    for i in 0..<maxLength {
        let p1 = i < parts1.count ? parts1[i] : 0
        let p2 = i < parts2.count ? parts2[i] : 0
        
        if p1 != p2 {
            return p1 < p2
        }
    }
    
    return false
}

func extractVersionOnly(_ version: String) -> String {
    guard let indexOfHypen = version.firstIndex(of: "-") else { return version }
    return String(version.prefix(upTo: indexOfHypen))
}

func verifyVersionInFiles(_ expectedVersion: String) throws {
    var errors: [String] = []
    let expectedVersion = args[2]
    
    for file in files {
        do {
            try verifyFile(file, expectedVersion)
        } catch let error as ErrorHandling {
            errors.append(error.message)
        }
    }

    for file in carthageFiles {
        do {
            try verifyCarthageFile(file, expectedVersion: expectedVersion)
        } catch let error as ErrorHandling {
            errors.append(error.message)
        }
    }
    
    let exactVersion = extractVersionOnly(expectedVersion)
    for file in restrictFiles {
        do {
            try verifyRestrictedFile(file, expectedVersion: exactVersion)
        } catch let error as ErrorHandling {
            errors.append(error.message)
        }
    }
    
    if !errors.isEmpty {
        exit(errormessage: "Could not validate all files: \n\(errors.joined(separator: "\n"))")
    }
    
    print("Successfully validated files version number")
}

func verifyFile(_ file: String, _ expectedVersion: String) throws {
    guard let fileHandler = try? open(file) else {
        throw FileError.fileNotFound(file)
    }
    
    let fileContent = fileHandler.read()
    let regexString = try getRegexString(for: file)
    let match = try? Regex(string: regexString, options: [.dotMatchesLineSeparators]).firstMatch(in: fileContent)
    
    guard let version = match?.captures[0] else {
        throw VersionError.versionNotFound(file)
    }
    
    guard version == expectedVersion else {
        throw VersionError.versionMismatch(file, version)
    }
    
    print("\(file) validated to have the correct version: \(version)")
}

func verifyRestrictedFile(_ file: String, expectedVersion: String) throws {
    guard let fileHandler = try? open(file) else {
        throw FileError.fileNotFound(file)
    }
    
    let fileContent = fileHandler.read()
    let marketingRegex = try? Regex(string: "MARKETING_VERSION\\s=\\s(?<version>[a-zA-z0-9\\.\\-]+)", options: [.dotMatchesLineSeparators])
    let currentProjectRegex = try? Regex(string: "CURRENT_PROJECT_VERSION\\s=\\s(?<version>[a-zA-z0-9\\.\\-]+)", options: [.dotMatchesLineSeparators])
    let match = marketingRegex?.firstMatch(in: fileContent) ?? currentProjectRegex?.firstMatch(in: fileContent)
    
    guard let version = match?.captures[0] else {
        throw VersionError.versionNotFound(file)
    }
    
    guard version == expectedVersion else {
        throw VersionError.versionMismatch(file, version)
    }
    
    print("\(file) validated to have the correct version: \(version)")
}

func verifyCarthageFile(_ file: String, expectedVersion: String) throws {
    let readFile = try open(file)
    let contents: String = readFile.read()
    guard let jsonData = contents.data(using: .utf8) else {
        throw FileError.unknownFile("Could not convert file contents to data")
    }
    
    let versionDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] ?? [:]
    
    guard versionDict[expectedVersion] != nil else {
        throw VersionError.versionNotFoundInCarthage(file, expectedVersion)
    }

    print("\(file) validated to contain the correct version: \(expectedVersion)")
}

func getRegexString(for file: String) throws -> String {
    if file.hasSuffix(".podspec") {
        if file == "./Tests/HybridSDKTest/HybridPod.podspec" {
            return "s\\.dependency\\s\"Sentry\\/HybridSDK\",\\s\"(?<version>[a-zA-z0-9\\.\\-]+)\""
        }
        return "\\ss\\.version\\s+=\\s\"(?<version>[a-zA-z0-9\\.\\-]+)\""
    } else if file.hasPrefix("./Package") && file.hasSuffix(".swift") {
        return "https:\\/\\/github\\.com\\/getsentry\\/sentry-cocoa\\/releases\\/download\\/(?<version>[a-zA-z0-9\\.\\-]+)\\/Sentry"
    } else if file == "./Sources/Sentry/SentryMeta.m" {
        return "static NSString \\*versionString = @\"(?<version>[a-zA-z0-9\\.\\-]+)\""
    }
    throw FileError.unknownFile(file)
}
