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
    name: "SentrySwiftLog",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySwiftLog",
            targets: ["SentrySwiftLog"]
        )
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
                .product(name: sentryProductName, package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "SentrySwiftLogTests",
            dependencies: [
                "SentrySwiftLog",
                .product(name: "Logging", package: "swift-log"),
                .product(name: sentryProductName, package: "sentry-cocoa")
            ]
        )
    ]
)
