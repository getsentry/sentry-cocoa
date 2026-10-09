// swift-tools-version: 6.1

import Foundation
import PackageDescription

func envFlag(_ name: String) -> Bool {
    getenv(name).map { String(cString: $0) == "1" } ?? false
}

let enableV10 = envFlag("SDK_V10")

// When SDK_V10 is set in the environment, Sentry exports the compile-from-source product
// as "Sentry" rather than "SentrySPM". Mirror that selection here.
let sentryProductName = enableV10 ? "Sentry" : "SentrySPM"

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
        .init(name: "V10", description: "Development-only V10 selection on supported trait tooling; use SDK_V10=1 with older tooling."),
        .default(enabledTraits: [])
    ],
    dependencies: [
        .package(
            name: "Sentry",
            path: "../..",
            traits: [
                "_SentryInternalUITestSupport",
                // V9 is implicit. Forward only the development V10 opt-in.
                .trait(name: "V10", condition: .when(traits: ["V10"]))
            ]
        )
    ],
    targets: [
        .target(
            name: "SentrySampleShared",
            dependencies: [
                .product(name: sentryProductName, package: "Sentry"),
                .product(name: "SentryObjC", package: "Sentry")
            ],
            path: "Sources/SentrySampleShared",
            resources: [
                .process("LoremIpsum.txt"),
                .process("screenshot.png")
            ],
            cSettings: enableV10
                ? [.define("SDK_V10", to: "1")]
                : [.define("SDK_V10", to: "1", .when(traits: ["V10"]))],
            swiftSettings: enableV10
                ? [.define("SDK_V10")]
                : [.define("SDK_V10", .when(traits: ["V10"]))]
        ),
        .target(
            name: "SentrySampleUITestShared",
            path: "Sources/SentrySampleUITestShared"
        )
    ],
    swiftLanguageModes: [.v5]
)
