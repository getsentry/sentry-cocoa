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

// The trait is only a compatibility marker for V10 project declarations.
// Version selection comes from the same environment as the SDK manifest.
var packageTraits: Set<Trait> = [.default(enabledTraits: [])]
if enableV10 {
    packageTraits.insert(.init(name: "V10", description: "Development-only compatibility marker. Requires SDK_V10=1."))
}

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
    traits: packageTraits,
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
                .product(name: sentryProductName, package: "Sentry"),
                .product(name: "SentryObjC", package: "Sentry")
            ],
            path: "Sources/SentrySampleShared",
            resources: [
                .process("LoremIpsum.txt"),
                .process("screenshot.png")
            ],
            cSettings: enableV10 ? [.define("SDK_V10", to: "1")] : [],
            swiftSettings: enableV10 ? [.define("SDK_V10")] : []
        ),
        .target(
            name: "SentrySampleUITestShared",
            path: "Sources/SentrySampleUITestShared"
        )
    ],
    swiftLanguageModes: [.v5]
)
