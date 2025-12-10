// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SentrySwiftyBeaver",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(
            name: "SentrySwiftyBeaver",
            targets: ["SentrySwiftyBeaver"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.0.0"),
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SentrySwiftyBeaver",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ]
        ),
        .testTarget(
            name: "SentrySwiftyBeaverTests",
            dependencies: [
                "SentrySwiftyBeaver",
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver")
            ]
        )
    ]
)
