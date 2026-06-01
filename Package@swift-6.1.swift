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
    // .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/Sentry.xcframework.zip",
        checksum: "29620f2fc671a3c1cb9d5c2ab99239f1e5d0be81affeaed6e5ee04fdfe2ebd7f" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/Sentry-Dynamic.xcframework.zip",
        checksum: "63953485095f2a350b5b5ee166a979dc5ff9ff5ab3d0eeb7a1872a63e8970884" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "934005c3b1be8a7053299b1f46710c8da302e8241f96701b932b4f1ae36575ce" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "b3a6b3a45d84d87dbcbd1e1ac6328af0d8b8217d7be0830acf5c84ab8891d0ed" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "ac7397ac628b1eebaff57390e61c96912bbbb78e4135fb1f05f607d12837f9fc" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    // .binaryTarget(
    //     name: "SentryObjC-Dynamic",
    //     url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.0-alpha.1/SentryObjC-Dynamic.xcframework.zip",
    //     checksum: "1f7923e90e881ae85c4456e65720898cb8c1dcb8548583d61097da1f0536621d" //SentryObjC-Dynamic
    // ),
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
            "SentryObjCCompat"
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
