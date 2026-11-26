// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SentryTestUtilsDynamic",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "SentryTestUtilsDynamic", type: .dynamic, targets: ["SentryTestUtilsDynamic"])
    ],
    traits: [
        .trait(name: "NoUIFramework", description: "Disable the UIKit test fixture.")
    ],
    targets: [
        .target(
            name: "SentryTestUtilsDynamic",
            path: "Sources",
            swiftSettings: [.define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))]
        )
    ],
    swiftLanguageModes: [.v5]
)
