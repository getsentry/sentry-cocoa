// swift-tools-version:5.5
#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

var products: [Product] = [
    .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
    .library(name: "SentryDistribution", targets: ["SentryDistribution"]),
    .library(name: "SentrySwiftLog", targets: ["Sentry", "SentrySwiftLog"]),
    .library(name: "SentryPulse", targets: ["Sentry", "SentryPulse"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.1/Sentry.xcframework.zip",
        checksum: "f187d5cc4f8c34533efb5b5ac74cab59ca5354c846d7230f3cbf8ecc81f3fa50" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.1/Sentry-Dynamic.xcframework.zip",
        checksum: "191d76b1228cd52745ec2c875b2b5ed3d319f435db025ac9cea9ba300c62bbc6" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "cbd168b1b496daf5dc9668520f64c58a1843645e6f335613db3f62e45bb64b90" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "c38f99b532807f79ef3b7960099ba1db0a3e4663e8f2838875e100fa5b78611b" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "6f3b991969a02f02878d052d0edf7076110f0ea577f84b2c5ad706a9bd302c54" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .target(
        name: "SentrySwiftUI",
        dependencies: ["Sentry", "SentryInternal"],
        path: "Sources/SentrySwiftUI",
        exclude: ["SentryInternal/", "module.modulemap"],
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target(
        name: "SentrySwiftLog",
        dependencies: ["Sentry", .product(name: "Logging", package: "swift-log")],
        path: "Sources/SentrySwiftLog",
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target(
        name: "SentryPulse",
        dependencies: ["Sentry", .product(name: "Pulse", package: "Pulse")],
        path: "Sources/SentryPulse",
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target(
        name: "SentryInternal",
        path: "Sources/SentrySwiftUI",
        sources: [
            "SentryInternal/"
        ],
        publicHeadersPath: "SentryInternal/"
    ),
    .target(
        name: "SentryCppHelper",
        dependencies: ["Sentry"],
        path: "Sources/SentryCppHelper",
        linkerSettings: [
         .linkedLibrary("c++")
        ]
    ),
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

let env = getenv("EXPERIMENTAL_SPM_BUILDS")
if let env = env, String(cString: env, encoding: .utf8) == "1" {
    products.append(.library(name: "SentrySPM", type: .dynamic, targets: ["SentryObjc"]))
    targets.append(contentsOf: [
        // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
        .target(
            name: "SentryHeaders",
            path: "Sources/Sentry", 
            sources: ["SentryDummyPublicEmptyClass.m"],
            publicHeadersPath: "Public"
        ),
        .target(
            name: "_SentryPrivate",
            dependencies: ["SentryHeaders"],
            path: "Sources/Sentry",
            sources: ["SentryDummyPrivateEmptyClass.m"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("include/HybridPublic")]),
        .target(
            name: "SentrySwift",
            dependencies: ["_SentryPrivate", "SentryHeaders"],
            path: "Sources/Swift",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"])
            ]),
        .target(
            name: "SentryObjc",
            dependencies: ["SentrySwift"],
            path: "Sources",
            exclude: ["Sentry/SentryDummyPublicEmptyClass.m", "Sentry/SentryDummyPrivateEmptyClass.m", "Swift", "SentrySwiftUI", "SentrySwiftLog", "SentryPulse", "Resources", "Configuration", "SentryCppHelper", "SentryDistribution", "SentryDistributionTests"],
            cSettings: [
                .headerSearchPath("Sentry/include/HybridPublic"),
                .headerSearchPath("Sentry"),
                .headerSearchPath("SentryCrash/Recording"),
                .headerSearchPath("SentryCrash/Recording/Monitors"),
                .headerSearchPath("SentryCrash/Recording/Tools"),
                .headerSearchPath("SentryCrash/Installations"),
                .headerSearchPath("SentryCrash/Reporting/Filters"),
                .headerSearchPath("SentryCrash/Reporting/Filters/Tools")])
    ])
}

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: products,
    dependencies: [
        // SPM doesn't support peer-dependencies, so users are locked into our declared version.
        // Using `from: "1.6.0"` covers 1.6.0 < 2.0.0, resolving minor versions automatically.
        // See develop-docs/DECISIONS.md for discussion.
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0")
        .package(url: "https://github.com/kean/Pulse", from: "5.0.0")
    ],
    targets: targets,
    cxxLanguageStandard: .cxx14
)
