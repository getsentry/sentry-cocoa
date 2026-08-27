// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SentrySampleShared",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySampleShared",
            targets: ["SentrySampleShared"]
        ),
        .library(
            name: "SentrySampleUITestShared",
            targets: ["SentrySampleUITestShared"]
        )
    ],
    traits: [
        .init(name: "V10", description: "Enable SDK V10 API changes.")
    ],
    dependencies: [
        .package(
            name: "Sentry",
            path: "../..",
            traits: [
                .defaults,
                "_SentryInternalUITestSupport",
                .trait(name: "V10", condition: .when(traits: ["V10"]))
            ]
        )
    ],
    targets: [
        .target(
            name: "SentrySampleShared",
            dependencies: [
                .product(name: "SentrySPM", package: "Sentry"),
                .product(name: "SentryObjC", package: "Sentry", condition: .when(traits: ["V10"]))
            ],
            path: "Sources/SentrySampleShared",
            resources: [
                .process("LoremIpsum.txt"),
                .process("screenshot.png")
            ],
            swiftSettings: [
                .define("SDK_V10", .when(traits: ["V10"]))
            ]
        ),
        .target(
            name: "SentrySampleUITestShared",
            path: "Sources/SentrySampleUITestShared"
        )
    ],
    swiftLanguageModes: [.v5]
)
