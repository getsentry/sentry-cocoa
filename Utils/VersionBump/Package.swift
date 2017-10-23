import PackageDescription

let package = Package(
    name: "VersionBump",
    dependencies: [
        .Package(url: "https://github.com/kareman/SwiftShell.git", "4.0.0"),
        .Package(url: "https://github.com/sharplet/Regex.git", "1.1.0"),
         ]
)
