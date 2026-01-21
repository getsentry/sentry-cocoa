// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SentrySwiftLog",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySwiftLog",
            targets: ["SentrySwiftLog"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.2.0")
    ],
    targets: [
        .target(
            name: "SentrySwiftLog",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "SentrySwiftLogTests",
            dependencies: [
                "SentrySwiftLog",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        )
    ]
)
