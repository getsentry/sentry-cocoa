import Foundation
import Regex
import SwiftShell

let fromVersionFile = "./Sentry.podspec"

let files = [
    "./Sentry.podspec",
    "./Sources/Sentry/SentryMeta.m",
    "./Sources/Configuration/Sentry.xcconfig"
]

// We upload the sample project to App Store Connect.
// The version for it in the Info.plist must be a period-separated list of at most three non-negative integers.
// Find out more at https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring"
// Therefore we remove the alpha and beta suffixes
let filesWithoutPreviewSuffix = [
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

func updateVersion(_ file: String, _ fromVersion: String, _ toVersion: String) throws {
    let readFile = try open(file)
    let contents: String = readFile.read()
    let newContents = contents.replacingOccurrences(of: fromVersion, with: toVersion)
    let overwriteFile = try! open(forWriting: file, overwrite: true)
    overwriteFile.write(newContents)
    overwriteFile.close()
}

func removePreviewSuffix(_ version: String) -> String {
    return version.split(separator: "-").first?.base ?? version
}

for match in Regex(semver, options: [.dotMatchesLineSeparators]).allMatches(in: fromFileContent) {
    let fromVersion = match.matchedString
    let toVersion = args[1]

    for file in files {
        try updateVersion(file, fromVersion, toVersion)
    }

    for file in filesWithoutPreviewSuffix {
        try updateVersion(file, removePreviewSuffix(fromVersion), removePreviewSuffix(toVersion))
    }
}
