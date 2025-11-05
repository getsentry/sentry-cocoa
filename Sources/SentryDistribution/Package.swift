// swift-tools-version:5.5

// NOTE:
// The distribution sample used to reference the repository’s root `Package.swift`, whose binary
// targets point at release artifacts that may not exist yet when we run CI before publishing. This
// trimmed-down manifest mirrors the relevant parts of the root package but only exposes the local
// `Sources/SentryDistribution` target so the sample can build against it without fetching unreleased
// binaries.

import PackageDescription

var products: [Product] = [
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

var targets: [Target] = [
    .target(name: "SentryDistribution", path: "./")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: products,
    targets: targets
)
