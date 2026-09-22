// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "CrashE2ERunner",
    products: [
        .executable(name: "CrashE2ERunner", targets: ["CrashE2ERunner"])
    ],
    targets: [
        .executableTarget(name: "CrashE2ERunner")
    ]
)
