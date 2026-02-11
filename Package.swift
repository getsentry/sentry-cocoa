// swift-tools-version:6.0

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
    .library(name: "SentrySPM", targets: ["SentrySPM"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.4.0/Sentry.xcframework.zip",
        checksum: "c0af612b43a4eacab4d38bda0a65b7a310295b3daadb95df2aa8251a9f6bdf6d" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.4.0/Sentry-Dynamic.xcframework.zip",
        checksum: "05f6925c228021e9e2bbdc9b609602de18a30f8192cba88d11aafb867ae24a5e" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.4.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "e351c4f85ae32e9180ceea4e8a3f470b44148658ba7e119fd4df7548afedca45" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.4.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "993d0e3cc5530e4b22737eb4aeeae1a84ad9182e8df958160e3e8ec1a8a4b5f0" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.4.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "70d0b5865e9ffb7c9f1c1f5bd0511cd8ffd335da895c5ad17ebc250c9d9694b6" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .target(
        name: "SentrySwiftUI",
        dependencies: ["Sentry"],
        path: "Sources/SentrySwiftUI",
        exclude: ["module.modulemap"],
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target(
        name: "SentryCppHelper",
        path: "Sources/SentryCppHelper",
        linkerSettings: [
            .linkedLibrary("c++")
        ]
    ),
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

// MARK: - SentrySPM: Compile-from-source product
//
// The "SentrySPM" product allows consumers to compile Sentry directly from source via SPM,
// as an alternative to the pre-built xcframework binary targets above. Consumers add the
// "SentrySPM" product as a dependency and use `import SentrySPM` in their source files.
//
// The import must be changed from `import Sentry` to `import SentrySPM` because the name
// "Sentry" is already taken by the binary xcframework target above. SPM does not
// allow two targets with the same name in a package, so the compile-from-source product
// needs a distinct name.
//
// ### Architecture:
//
// The SDK source is split across Objective-C (Sources/Sentry/, Sources/SentryCrash/) and
// Swift (Sources/Swift/). SPM requires each target to contain a single language, so we
// split the source into separate targets:
//
//   SentryHeaders      - Exposes public ObjC headers (Sources/Sentry/Public/)
//   _SentryPrivate     - Exposes private/internal ObjC headers (Sources/Sentry/include/)
//   SentrySwift        - All Swift source (Sources/Swift/), depends on the ObjC headers
//   SentryObjCInternal - All ObjC/C source (Sources/Sentry/, Sources/SentryCrash/),
//                        depends on SentrySwift for Swift-to-ObjC interop
//
// The consumer-facing module is "SentrySPM", a thin Swift wrapper target that re-exports
// both SentryObjCInternal and SentrySwift via @_exported import (see Sources/SentrySPM/).
// This gives consumers a single `import SentrySPM` that provides access to the full API
// (both ObjC types like SentrySDK/Breadcrumb and Swift types like Options/.sentryTrace()).
//
// Without this wrapper, consumers would need two imports:
//   import SentryObjCInternal  // ObjC types
//   import SentrySwift         // Swift types
// which leaks internal module structure. The wrapper avoids that.
//
// Note: SentryObjCInternal uses path "Sources" (the repo root Sources/ directory) and must
// exclude all subdirectories that belong to other targets to avoid "mixed language source
// files" errors from SPM. The SentrySPM directory is excluded for this reason.

targets += [
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
        publicHeadersPath: "include"),
    .target(
        name: "SentrySwift",
        dependencies: ["_SentryPrivate", "SentryHeaders"],
        path: "Sources/Swift",
        swiftSettings: [
            .unsafeFlags(["-enable-library-evolution"])
        ]),

    // SentryObjCInternal compiles all ObjC/C sources from the repo. Named "Internal"
    // to reserve "SentryObjC" for a future public Objective-C wrapper around the SDK.
    .target(
        name: "SentryObjCInternal",
        dependencies: ["SentrySwift"],
        path: "Sources",
        exclude: ["Sentry/SentryDummyPublicEmptyClass.m", "Sentry/SentryDummyPrivateEmptyClass.m", "Swift", "SentrySwiftUI", "SentrySPM", "Resources", "Configuration", "SentryCppHelper", "SentryDistribution", "SentryDistributionTests"],
        cSettings: [
            .headerSearchPath("Sentry"),
            .headerSearchPath("SentryCrash/Recording"),
            .headerSearchPath("SentryCrash/Recording/Monitors"),
            .headerSearchPath("SentryCrash/Recording/Tools"),
            .headerSearchPath("SentryCrash/Installations"),
            .headerSearchPath("SentryCrash/Reporting/Filters"),
            .headerSearchPath("SentryCrash/Reporting/Filters/Tools")]),

    // Thin wrapper that re-exports both modules so consumers only need `import SentrySPM`.
    // See Sources/SentrySPM/SentrySPM.swift for the @_exported imports.
    .target(
        name: "SentrySPM",
        dependencies: ["SentryObjCInternal", "SentrySwift"],
        path: "Sources/SentrySPM")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
