import Foundation
import Regex
import SwiftShell

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
    "./Sources/Configuration/SentrySwiftUI.xcconfig",
    "./Samples/Shared/Config/Versioning.xcconfig"
]

let args = CommandLine.arguments

let semver: StaticString = "([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+)?"
let regex = Regex(semver)
if regex.firstMatch(in: args[2]) == nil {
    exit(errormessage: "version number must fit x.x.x format" )
}

if args[1] == "--verify" {
    try verifyVersionInFiles()
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

func extractVersionOnly(_ version: String) -> String {
    guard let indexOfHypen = version.firstIndex(of: "-") else { return version }
    return String(version.prefix(upTo: indexOfHypen))
}

func verifyVersionInFiles() throws {
    let expectedVersion = args[2]
    
    for file in files {
        let fileHandler = try open(file)
        let fileContent: String = fileHandler.read()

        var regexString: String = ""
        if file.hasSuffix(".podspec") {
            if file == "./Tests/HybridSDKTest/HybridPod.podspec" {
                regexString = "s\\.dependency\\s\"Sentry\\/HybridSDK\",\\s\"(?<version>[a-zA-z0-9\\.\\-]+)\""
            } else {
                regexString = "\\ss\\.version\\s+=\\s\"(?<version>[a-zA-z0-9\\.\\-]+)\""
            }
        } else if file == "./Package.swift" {
            regexString = "https:\\/\\/github\\.com\\/getsentry\\/sentry-cocoa\\/releases\\/download\\/(?<version>[a-zA-z0-9\\.\\-]+)\\/Sentry"
        } else if file == "./Sources/Sentry/SentryMeta.m" {
            regexString = "static NSString \\*versionString = @\"(?<version>[a-zA-z0-9\\.\\-]+)\""
        }
        let match = try? Regex(string: regexString, options: [.dotMatchesLineSeparators]).firstMatch(in: fileContent)
        let version = match?.captures[0] ?? "Version Not Found"
        if version != expectedVersion {
            exit(errormessage: "Unexpected version \(version) found for file '\(file)'")
        }
    }
    
    let exactVersion = extractVersionOnly(expectedVersion)
    for file in restrictFiles {
        let fileHandler = try open(file)
        let fileContent: String = fileHandler.read()
        
        let marketingRegex = try? Regex(string: "MARKETING_VERSION\\s=\\s(?<version>[a-zA-z0-9\\.\\-]+)", options: [.dotMatchesLineSeparators])
        let currentProjectRegex = try? Regex(string: "CURRENT_PROJECT_VERSION\\s=\\s(?<version>[a-zA-z0-9\\.\\-]+)", options: [.dotMatchesLineSeparators])
        let match = marketingRegex?.firstMatch(in: fileContent) ?? currentProjectRegex?.firstMatch(in: fileContent)
        let version = match?.captures[0] ?? "Version Not Found"
        if version != exactVersion {
            exit(errormessage: "Unexpected version \(version) found for file '\(file)'")
        }
    }
    
    print("Successfuly validated files version number")
}
