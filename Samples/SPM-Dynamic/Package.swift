// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM-Dynamic",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "SPM-Dynamic", type: .dynamic, targets: ["SPM-Dynamic"])
    ],
    dependencies: [
        // branch is replaced in CI to the current sha
        .package(name: "Sentry", url: "https://github.com/getsentry/sentry-cocoa", .branch("master") )
    ],
    targets: [
        .target(
            name: "SPM-Dynamic",
            dependencies: ["Sentry"], 
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ])
    ]
)
