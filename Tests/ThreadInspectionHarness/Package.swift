// swift-tools-version:6.0
import Foundation
import PackageDescription

// Use the published SDK-compatible backport by default, not the incompatible develop line where
// #913 was merged. KSCRASH_PATH remains available for upstream-development testing.
let kscrashDependency: Package.Dependency
if let kscrashPath = ProcessInfo.processInfo.environment["KSCRASH_PATH"] {
    kscrashDependency = .package(name: "KSCrash", path: kscrashPath)
} else {
    kscrashDependency = .package(
        url: "https://github.com/supervacuus/KSCrash.git",
        revision: "391bf0a9569b6c1aa9df30b3fa4bcabbc0a07e7a"
    )
}

let package = Package(
    name: "ThreadInspectionHarness",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "ThreadSnapshotBenchmark", targets: ["ThreadSnapshotBenchmark"])
    ],
    dependencies: [kscrashDependency],
    targets: [
        .target(
            name: "ThreadSnapshot",
            dependencies: [.product(name: "RecordingCore", package: "KSCrash")],
            cSettings: [.define("SDK_V10", to: "1")]
        ),
        .executableTarget(
            name: "ThreadSnapshotBenchmark",
            dependencies: ["ThreadSnapshot", .product(name: "RecordingCore", package: "KSCrash")]
        ),
        .testTarget(
            name: "ThreadSnapshotTests",
            dependencies: ["ThreadSnapshot", .product(name: "RecordingCore", package: "KSCrash")]
        )
    ]
)
