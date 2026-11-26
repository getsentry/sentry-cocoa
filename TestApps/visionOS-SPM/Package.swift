// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "visionOS-SPM",
    platforms: [.visionOS(.v1)],
    products: [
        .executable(name: "visionOS-SPM", targets: ["visionOS-SPM"])
    ],
    dependencies: [
        // branch is replaced in CI to the current sha
        .package(name: "Sentry", path: "../../../sentry-cocoa")
    ],
    targets: [
        .executableTarget(
            name: "visionOS-SPM",
            dependencies: [.product(name: "Sentry", package: "Sentry")],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ])
    ]
)
