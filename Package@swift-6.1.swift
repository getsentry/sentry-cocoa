// swift-tools-version:6.1

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
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.12.0/Sentry.xcframework.zip",
        checksum: "3e56f5ba2ba2052a80fb117e24bdf73d9c448f4be7c3c0c0a558e4709442f62e" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.12.0/Sentry-Dynamic.xcframework.zip",
        checksum: "c0732245f962cd02b5d1857a450bda3ad28efc4c278c7a21c04e33e7a6044956" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.12.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "e5debf12dc731915faf09673df6ec71e8a4559f3470acc2c64543c07194302f8" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.12.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "cf96522256ab0f724645a097f91aea08f5db80f3565d9932411007a43784be6a" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.12.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "95089466a74093c97b13f39f01c14dd1d1816ab376fff72c11c4aad47aa5a7c5" //Sentry-WithoutUIKitOrAppKit-WithARM64e
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

// Targets required to support compile-from-source builds via SPM.
products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
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
            .unsafeFlags(["-enable-library-evolution"]),
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ]),

    // SentryObjCInternal compiles all ObjC/C sources from the repo. Named "Internal"
    // to reserve "SentryObjC" for a future public Objective-C wrapper around the SDK.
    .target(
        name: "SentryObjCInternal",
        dependencies: ["SentrySwift"],
        path: "Sources",
        exclude: [
            "Sentry/SentryDummyPublicEmptyClass.m",
            "Sentry/SentryDummyPrivateEmptyClass.m",
            "Swift",
            "SentrySwiftUI",
            "Resources",
            "Configuration",
            "SentryCppHelper",
            "SentryDistribution",
            "SentryDistributionTests",
            "SentryObjC",
            "SentryObjCBridge",
            "SentryObjCTypes"
        ],
        cSettings: [
            .headerSearchPath("Sentry"),
            .headerSearchPath("SentryCrash/Recording"),
            .headerSearchPath("SentryCrash/Recording/Monitors"),
            .headerSearchPath("SentryCrash/Recording/Tools"),
            .headerSearchPath("SentryCrash/Installations"),
            .headerSearchPath("SentryCrash/Reporting/Filters"),
            .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ])
]

// BEGIN:OBJC_WRAPPER
// Swift bridge that exposes SDK functionality to pure ObjC code (no modules)
products.append(.library(name: "SentryObjC", targets: ["SentryObjCInternal", "SentryObjCTypes", "SentryObjCBridge", "SentryObjC"]))
targets += [
    // Frozen public ObjC ABI — pure data carriers, depends only on Foundation.
    // Both SentryObjCBridge and SentryObjC depend on this so they reference
    // the same authoritative type declarations.
    .target(
        name: "SentryObjCTypes",
        path: "Sources/SentryObjCTypes",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ]),
    .target(
        name: "SentryObjCBridge",
        dependencies: ["SentryObjCInternal", "SentryObjCTypes"],
        path: "Sources/SentryObjCBridge"),
    .testTarget(
        name: "SentryObjCBridgeTests",
        dependencies: ["SentryObjCBridge", "SentryObjCTypes", "SentrySwift"],
        path: "Tests/SentryObjCBridgeTests"),

    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCInternal", "SentryObjCBridge", "SentryObjCTypes"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ]
    )
]
// END:OBJC_WRAPPER

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable.")
    ],
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
