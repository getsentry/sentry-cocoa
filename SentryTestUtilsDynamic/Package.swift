// swift-tools-version:6.0
import PackageDescription

// Keep this as a separate package: a same-package target dependency is statically linked,
// even when a dynamic product also exposes it. The swizzling tests require a distinct image.
let package = Package(
    name: "SentryTestUtilsDynamic",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [.library(name: "SentryTestUtilsDynamic", type: .dynamic, targets: ["SentryTestUtilsDynamic"])],
    targets: [.target(name: "SentryTestUtilsDynamic", path: "Sources")],
    swiftLanguageModes: [.v5]
)
