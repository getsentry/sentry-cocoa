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
    // BEGIN:BINARY_PRODUCTS
    .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
    .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"]),
    .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"]),
    // END:BINARY_PRODUCTS
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

var targets: [Target] = [
    // BEGIN:BINARY_TARGETS
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/Sentry.xcframework.zip",
        checksum: "28ef56436f9628f2e2c6fbea847004f78a4082cbcba1293b1c17983641995da7" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/Sentry-Dynamic.xcframework.zip",
        checksum: "4c6a044bbffea1564b81516d02b7f386829a572696195dc5258471e4ccc95251" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "7158ee9222f4da3be1aef1388241149b5276df54f51d094b4c1817a77597cd49" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "432e07636195eb193f128b6be74b4b9491100500ab19106958f34be777b7892f" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "234a9df9b464a055c8a27b46b9957984a7755336d75b2cead99978d73215245c" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .binaryTarget(
        name: "SentryObjC-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/SentryObjC-Dynamic.xcframework.zip",
        checksum: "4f3324536bf0ca1fa0fdf0e8c4d53e5999ea267748a3e1c9137c1f1b6156c1bb" //SentryObjC-Dynamic
    ),
    .binaryTarget(
        name: "SentryObjC-Static",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.17.0/SentryObjC-Static.xcframework.zip",
        checksum: "ab04fa1131c0826a5ee1701d6324d9b3cdff0caaf9dd74f240de6a0b720a1192" //SentryObjC-Static
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
    // END:BINARY_TARGETS
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
            .unsafeFlags(["-enable-library-evolution"])
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
            "SentryObjCCompat"
        ],
        cSettings: [
            .headerSearchPath("Sentry"),
            .headerSearchPath("SentryCrash/Recording"),
            .headerSearchPath("SentryCrash/Recording/Monitors"),
            .headerSearchPath("SentryCrash/Recording/Tools"),
            .headerSearchPath("SentryCrash/Installations"),
            .headerSearchPath("SentryCrash/Reporting/Filters"),
            .headerSearchPath("SentryCrash/Reporting/Filters/Tools")])
]

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat"),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ]
    )
]
// END:OBJC_WRAPPER

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
