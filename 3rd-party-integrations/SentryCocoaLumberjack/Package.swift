// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SentryCocoaLumberjack",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(
            name: "SentryCocoaLumberjack",
            targets: ["SentryCocoaLumberjack"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.8.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.5.1")
    ],
    targets: [
        .target(
            name: "SentryCocoaLumberjack",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "SentryCocoaLumberjackTests",
            dependencies: [
                "SentryCocoaLumberjack",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        )
    ]
)
