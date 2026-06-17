// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SentrySampleShared",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SentrySampleShared",
            targets: ["SentrySampleShared"]
        ),
        .library(
            name: "SentrySampleUITestShared",
            targets: ["SentrySampleUITestShared"]
        )
    ],
    dependencies: [
        .package(name: "Sentry", path: "../..")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SentrySampleShared",
            dependencies: [
                .product(name: "SentrySPM", package: "Sentry")
            ],
            path: "Sources/SentrySampleShared",
            resources: [
                .process("LoremIpsum.txt"),
                .process("screenshot.png")
            ]
        ),
        .target(
            name: "SentrySampleUITestShared",
            path: "Sources/SentrySampleUITestShared",
            publicHeadersPath: "include"
        )
    ],
    swiftLanguageModes: [.v5]
)
