// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Both producers expose Sentry; only the dependency location changes.
// Local framework paths are relative to this package.
let spmFramework = ProcessInfo.processInfo.environment["SENTRY_XCFRAMEWORK"]
let sdkTargets: [Target] = spmFramework.map { path in
    [.binaryTarget(name: "Sentry", path: path)]
} ?? []
let sdkDependencies: [Target.Dependency] = spmFramework == nil
    ? [.product(name: "Sentry-Dynamic", package: "Sentry")]
    : [.byName(name: "Sentry")]

let package = Package(
    name: "SPM-Dynamic",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "SPM-Dynamic", targets: ["SPM-Dynamic"])
    ],
    dependencies: spmFramework == nil ? [
        .package(name: "Sentry", path: "../../../sentry-cocoa")
    ] : [],
    targets: sdkTargets + [
        .target(
            name: "ObjCConsumer",
            dependencies: sdkDependencies,
            cSettings: [
                .unsafeFlags(["-Werror=quoted-include-in-framework-header"])
            ]),
        .executableTarget(
            name: "SPM-Dynamic",
            dependencies: sdkDependencies + ["ObjCConsumer"],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ],
            linkerSettings: [
                // Xcode copies the framework beside this command-line executable.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"])
            ])
    ]
)
