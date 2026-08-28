// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SentryCocoaLumberjack",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentryCocoaLumberjack",
            targets: ["SentryCocoaLumberjack"]
        )
    ],
    traits: [
        .default(enabledTraits: ["SentryFromBinary"]),
        .init(name: "SentryFromBinary", description: "Use precompiled Sentry binary xcframeworks."),
        .init(name: "SentryFromSource", description: "Build Sentry from source instead of using precompiled binaries.")
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.8.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.26.1")
    ],
    targets: [
        .target(
            name: "SentryCocoaLumberjack",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["SentryFromBinary"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"]))
            ],
            swiftSettings: [
                .define("SENTRY_FROM_BINARY", .when(traits: ["SentryFromBinary"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        ),
        .testTarget(
            name: "SentryCocoaLumberjackTests",
            dependencies: [
                "SentryCocoaLumberjack",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
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
