// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SentryPulse",
    platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentryPulse",
            targets: ["SentryPulse"]
        )
    ],
    traits: [
        .default(enabledTraits: ["SentryFromBinary"]),
        .init(name: "SentryFromBinary", description: "Use precompiled Sentry binary xcframeworks."),
        .init(name: "SentryFromSource", description: "Build Sentry from source instead of using precompiled binaries.")
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", from: "5.0.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.26.0")
    ],
    targets: [
        .target(
            name: "SentryPulse",
            dependencies: [
                .product(name: "Pulse", package: "Pulse"),
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["SentryFromBinary"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"]))
            ],
            swiftSettings: [
                .define("SENTRY_FROM_BINARY", .when(traits: ["SentryFromBinary"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        ),
        .testTarget(
            name: "SentryPulseTests",
            dependencies: [
                "SentryPulse",
                .product(name: "Pulse", package: "Pulse"),
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["SentryFromBinary"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"]))
            ],
            swiftSettings: [
                .define("SENTRY_FROM_BINARY", .when(traits: ["SentryFromBinary"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        )
    ]
)
