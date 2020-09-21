// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "VersionBump",
    products: [
        .executable(name: "VersionBump", targets: ["VersionBump"])
    ],
    dependencies: [
        // We need to use the 5.1.0-beta.1, because otherwise we can't compile with Swift 5.3
        // see https://github.com/kareman/SwiftShell/releases/tag/5.1.0-beta.1
        .package(url: "https://github.com/kareman/SwiftShell.git", from: "5.1.0-beta.1"),
        .package(url: "https://github.com/sharplet/Regex.git", from: "2.1.1")
    ],
    targets: [
        .target(
            name: "VersionBump",
            dependencies: ["SwiftShell", "Regex"],
            path: "./")
    ]
)
