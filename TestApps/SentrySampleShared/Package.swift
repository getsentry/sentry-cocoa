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
    traits: [.default(enabledTraits: [])],
    dependencies: [
        .package(
            name: "Sentry",
            path: "../..",
            traits: ["_SentryInternalUITestSupport"]
        )
    ],
    targets: [
        .target(
            name: "SentrySampleShared",
            dependencies: [
                .product(name: "Sentry", package: "Sentry"),
                .product(name: "SentryObjC", package: "Sentry")
            ],
            path: "Sources/SentrySampleShared",
            resources: [
                .process("LoremIpsum.txt"),
                .process("screenshot.png")
            ],
            cSettings: [.define("SDK_V10", to: "1")],
            swiftSettings: [.define("SDK_V10")]
        ),
        .target(
            name: "SentrySampleUITestShared",
            path: "Sources/SentrySampleUITestShared"
        )
    ],
    swiftLanguageModes: [.v5]
)
