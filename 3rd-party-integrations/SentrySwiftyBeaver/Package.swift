// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SentrySwiftyBeaver",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySwiftyBeaver",
            targets: ["SentrySwiftyBeaver"]
        )
    ],
    traits: [
        .default(enabledTraits: ["PrecompiledSentry"]),
        .init(name: "PrecompiledSentry", description: "Use precompiled Sentry binary xcframeworks."),
        .init(name: "SentryFromSource", description: "Build Sentry from source instead of using precompiled binaries.")
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.25.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SentrySwiftyBeaver",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["PrecompiledSentry"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"])),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ],
            swiftSettings: [
                .define("SENTRY_PRECOMPILED", .when(traits: ["PrecompiledSentry"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        ),
        .testTarget(
            name: "SentrySwiftyBeaverTests",
            dependencies: [
                "SentrySwiftyBeaver",
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["PrecompiledSentry"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"])),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ],
            swiftSettings: [
                .define("SENTRY_PRECOMPILED", .when(traits: ["PrecompiledSentry"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        )
    ]
)
