// swift-tools-version:6.0

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

let enableKSCrash = if let enableKSCrash = getenv("ENABLE_KSCRASH") {
    String(cString: enableKSCrash) == "1"
} else {
    false
}

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
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/Sentry.xcframework.zip",
        checksum: "e533fa9f83e890d0f2f2306b98e1d288248a077888c9ac0e5d7abe74d5fd761a" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/Sentry-Dynamic.xcframework.zip",
        checksum: "7e14f6400c79db0af855155dd2d5f022b8c1b838ef2ad5ba949f773cbfc06c76" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "1a427b37d2d207252392fd43b9d2372e8dbea7ba633a231879c273fabf656b10" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "fe651b7c59b8ece75f327cb449ebc3dc2b25dc8fd8ec5909be5b6b634d42d302" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "388f0df09e90ccdf1b121e3f8ca10cc2c954c204c1021e308c2cdeb530ffc311" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .binaryTarget(
        name: "SentryObjC-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/SentryObjC-Dynamic.xcframework.zip",
        checksum: "eb9edfc08b38c545a4a8010ef4e8448013865b95ecb1d07c9d9367cef7354243" //SentryObjC-Dynamic
    ),
    .binaryTarget(
        name: "SentryObjC-Static",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.0/SentryObjC-Static.xcframework.zip",
        checksum: "bf346639296e7fe27e1a75b061abc4777c705dd552bc58228f9c664e22f551cf" //SentryObjC-Static
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
products.append(.library(name: "Sentry+KSCrash", targets: ["SentryObjCInternal"]))

let sentrySwiftTarget: Target = .target(
    name: "SentrySwift",
    dependencies: ["_SentryPrivate", "SentryHeaders"],
    path: "Sources/Swift",
    swiftSettings: [
        .unsafeFlags(["-enable-library-evolution"])
    ]
)

if enableKSCrash {
    sentrySwiftTarget.dependencies.append(.product(name: "Installations", package: "KSCrash"))
    sentrySwiftTarget.swiftSettings?.append(.define("ENABLE_KSCRASH"))
}

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

    sentrySwiftTarget,

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

let packageDependencies: [Package.Dependency] = enableKSCrash ? [.package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.6.0-beta.3")] : []

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
