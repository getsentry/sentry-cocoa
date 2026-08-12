// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SentrySwiftLog",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySwiftLog",
            targets: ["SentrySwiftLog"]
        )
    ],
    traits: [
        .default(enabledTraits: ["SentryFromBinary"]),
        .init(name: "SentryFromBinary", description: "Use precompiled Sentry binary xcframeworks."),
        .init(name: "SentryFromSource", description: "Build Sentry from source instead of using precompiled binaries.")
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.25.0")
    ],
    targets: [
        .target(
            name: "SentrySwiftLog",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sentry", package: "sentry-cocoa", condition: .when(traits: ["SentryFromBinary"])),
                .product(name: "SentrySPM", package: "sentry-cocoa", condition: .when(traits: ["SentryFromSource"]))
            ],
            swiftSettings: [
                .define("SENTRY_FROM_BINARY", .when(traits: ["SentryFromBinary"])),
                .define("SENTRY_FROM_SOURCE", .when(traits: ["SentryFromSource"]))
            ]
        ),
        .testTarget(
            name: "SentrySwiftLogTests",
            dependencies: [
                "SentrySwiftLog",
                .product(name: "Logging", package: "swift-log"),
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
