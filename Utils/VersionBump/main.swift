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

let args = CommandLine.arguments

let semver: StaticString = "([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+)?"
let regex = Regex(semver)
if regex.firstMatch(in: args[1]) == nil {
    exit(errormessage: "version number must fit x.x.x format" )
}

let fromVersionFileHandler = try open(fromVersionFile)
let fromFileContent: String = fromVersionFileHandler.read()

if let match = Regex(semver, options: [.dotMatchesLineSeparators]).firstMatch(in: fromFileContent) {
    var fromVersion = match.matchedString
    var toVersion = args[1]

    for file in files {
        try updateVersion(file, fromVersion, toVersion)
    }
    
    fromVersion = extractVersionOnly(fromVersion)
    toVersion = extractVersionOnly(toVersion)
    
    try updateVersion("./Sources/Configuration/Versioning.xcconfig", fromVersion, toVersion)
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
