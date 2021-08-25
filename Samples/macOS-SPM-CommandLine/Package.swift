// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "macOS-SPM-CommandLine",
    dependencies: [
        // branch is replaced in CI to the current sha
        .package(name: "Sentry", url: "https://github.com/getsentry/sentry-cocoa", .branch("master") )
    ],
    targets: [
        .target(
            name: "macOS-SPM-CommandLine",
            dependencies: ["Sentry"], 
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ])
    ]
)
