// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPM-Dynamic",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "SPM-Dynamic", targets: ["SPM-Dynamic"])
    ],
    dependencies: [
        // branch is replaced in CI to the current sha
        .package(name: "Sentry", path: "../../../sentry-cocoa")
    ],
    targets: [
        .target(
            name: "SPM-Dynamic",
            dependencies: [.product(name: "Sentry-Dynamic", package: "Sentry")],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ])
    ]
)
