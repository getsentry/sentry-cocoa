// swift-tools-version:6.0
import PackageDescription

// A separate package product is required: an intra-package target dependency links statically,
// even when the root package also declares a dynamic library product for that target.
let package = Package(
    name: "SentryTestUtilsDynamic",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "SentryTestUtilsDynamic", type: .dynamic, targets: ["SentryTestUtilsDynamic"])
    ],
    targets: [
        .target(name: "SentryTestUtilsDynamic", path: "Sources")
    ],
    swiftLanguageModes: [.v5]
)
