// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// The path is relative to this package. The downloaded framework is the only SDK dependency.
let sourceFramework = ProcessInfo.processInfo.environment["SENTRY_SOURCE_XCFRAMEWORK"]
let sdkTargets: [Target] = sourceFramework.map { path in
    [
        .binaryTarget(name: "SentrySwift", path: path),
        .target(name: "ObjCConsumer", dependencies: ["SentrySwift"])
    ]
} ?? []
let sdkDependencies: [Target.Dependency] = sourceFramework == nil
    ? [.product(name: "Sentry-Dynamic", package: "Sentry")]
    : ["SentrySwift", "ObjCConsumer"]

let package = Package(
    name: "SPM-Dynamic",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "SPM-Dynamic", targets: ["SPM-Dynamic"])
    ],
    dependencies: sourceFramework == nil ? [
        .package(name: "Sentry", path: "../../../sentry-cocoa")
    ] : [],
    targets: sdkTargets + [
        .target(
            name: "SPM-Dynamic",
            dependencies: sdkDependencies,
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ] + (sourceFramework == nil ? [] : [.define("SENTRY_SOURCE_FRAMEWORK")]))
    ]
)
