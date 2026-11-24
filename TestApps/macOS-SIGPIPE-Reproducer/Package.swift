// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "macOS-SIGPIPE-Reproducer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "sentry-cocoa", path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "macOS-SIGPIPE-Reproducer",
            dependencies: [
                .product(name: "SentrySPM", package: "sentry-cocoa")
            ]
        )
    ]
)
