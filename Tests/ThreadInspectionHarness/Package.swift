// swift-tools-version:6.0
import Foundation
import PackageDescription

// Use the SDK's 2.6.1 fork with the C++ terminate fix and reserved-thread lookup (#913).
// KSCRASH_PATH remains available for upstream-development testing.
let kscrashDependency: Package.Dependency
if let kscrashPath = ProcessInfo.processInfo.environment["KSCRASH_PATH"] {
    kscrashDependency = .package(name: "KSCrash", path: kscrashPath)
} else {
    kscrashDependency = .package(
        url: "https://github.com/getsentry/KSCrash.git",
        revision: "c00af21aabcd2f84983abdcb2063c9446a524e74"
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
            dependencies: [.product(name: "RecordingCore", package: "KSCrash")]
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
