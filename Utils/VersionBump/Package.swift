// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "VersionBump",
    products: [
        .executable(name: "VersionBump", targets: ["VersionBump"])
    ],
    dependencies: [
        .package(url: "https://github.com/kareman/SwiftShell.git", from: "5.1.0"),
        .package(url: "https://github.com/sharplet/Regex.git", from: "2.1.1")
    ],
    targets: [
        .target(
            name: "VersionBump",
            dependencies: ["SwiftShell", "Regex"],
            path: "./")
    ]
)
