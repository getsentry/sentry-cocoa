import PackageDescription

let package = Package(
    name: "VersionBump",
    dependencies: [
        .Package(url: "https://github.com/kareman/SwiftShell.git", "3.0.0-beta"),
        .Package(url: "https://github.com/sharplet/Regex.git", majorVersion: 0, minor: 4),
         ]
)
