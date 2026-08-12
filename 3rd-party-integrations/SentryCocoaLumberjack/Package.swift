// swift-tools-version:6.0

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

func envFlag(_ name: String) -> Bool {
    getenv(name).map { String(cString: $0) == "1" } ?? false
}

let sentryProductName = envFlag("SENTRY_COCOA_SOURCE_BUILD") ? "SentrySPM" : "Sentry"

let package = Package(
    name: "SentryCocoaLumberjack",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentryCocoaLumberjack",
            targets: ["SentryCocoaLumberjack"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.8.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.25.0")
    ],
    targets: [
        .target(
            name: "SentryCocoaLumberjack",
            dependencies: [
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: sentryProductName, package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "SentryCocoaLumberjackTests",
            dependencies: [
                "SentryCocoaLumberjack",
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: sentryProductName, package: "sentry-cocoa")
            ]
        )
    ]
)
