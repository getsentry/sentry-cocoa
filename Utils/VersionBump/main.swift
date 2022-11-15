import Foundation
import Regex
import SwiftShell

let fromVersionFile = "./Sentry.podspec"

let files = [
    "./Sentry.podspec",
    "./SentryPrivate.podspec",
    "./SentrySwiftUI.podspec",
    "./Sources/Sentry/SentryMeta.m",
    "./Sources/Configuration/Sentry.xcconfig",
    "./Samples/iOS-Swift/iOS-Swift.xcodeproj/project.pbxproj"
]

let args = CommandLine.arguments

let semver: StaticString = "([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+)?"
let regex = Regex(semver)
if regex.firstMatch(in: args[1]) == nil {
    exit(errormessage: "version number must fit x.x.x format" )
}

let fromVersionFileHandler = try open(fromVersionFile)
let fromFileContent: String = fromVersionFileHandler.read()

for match in Regex(semver, options: [.dotMatchesLineSeparators]).allMatches(in: fromFileContent) {
    let fromVersion = match.matchedString
    let toVersion = args[1]

    for file in files {
        try updateVersion(file, fromVersion, toVersion)
    }
}

func updateVersion(_ file: String, _ fromVersion: String, _ toVersion: String) throws {
    let readFile = try open(file)
    let contents: String = readFile.read()
    let newContents = contents.replacingOccurrences(of: fromVersion, with: toVersion)
    let overwriteFile = try! open(forWriting: file, overwrite: true)
    overwriteFile.write(newContents)
    overwriteFile.close()
}
