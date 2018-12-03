import Foundation
import SwiftShell
import Regex

let files = [
    "./Sentry.podspec",
    "./Sources/Sentry/SentryClient.m",
    "./Sources/Configuration/Sentry.xcconfig",
]

let args = CommandLine.arguments

let regex = Regex("[0-9]+\\.[0-9]+\\.[0-9]+")
if regex.firstMatch(in: args[1]) == nil || regex.firstMatch(in: args[2]) == nil {
    exit(errormessage: "version number must bit 0.0.0 format" )
}

let fromVersion = args[1]
let toVersion = args[2]

for file in files {
    let readFile = try open(file)
    let contents: String = readFile.read()
    let newContents = contents.replacingOccurrences(of: fromVersion, with: toVersion)
    let overwriteFile = try! open(forWriting: file, overwrite: true)
    overwriteFile.write(newContents)
    overwriteFile.close()
}
