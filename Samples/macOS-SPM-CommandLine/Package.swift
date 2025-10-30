// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "macOS-SPM-CommandLine",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(name: "Sentry", path: "../../../sentry-cocoa")
    ],
    targets: [
        .target(
            name: "macOS-SPM-CommandLine",
            dependencies: ["Sentry", .product(name: "SentrySwiftUI", package: "Sentry")],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ])
    ]
)
