// swift-tools-version:6.2

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
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/Sentry.xcframework.zip",
        checksum: "5eeef9ad95be6b5965296e09ba41c5390382fe84988b15f1615cd0cc3fa7caca" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/Sentry-Dynamic.xcframework.zip",
        checksum: "561d7f9124a46188c5b8d62f73a8474b45a11f18c73c5710f2dfc9bc1f3aaf45" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "0df21e8a965959aae2bcc0da881970236d31857368066340e1b28eaf94a721ad" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "c6c0e6036b477a2a6e480859b07b10d67fb24f40f6d0414305a78f9a05ae2d6a" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "b4bd6e0fbd2be9c8eb5d99836f8526a8b32c7dbba8ebd2e6db7ca0240d6a72b1" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .binaryTarget(
        name: "SentryObjC-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/SentryObjC-Dynamic.xcframework.zip",
        checksum: "7f16d38e43ebfdd2d1a8b7a71e22f200810d1857a9a26fafceff4853cd27a9d3" //SentryObjC-Dynamic
    ),
    .binaryTarget(
        name: "SentryObjC-Static",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.22.0/SentryObjC-Static.xcframework.zip",
        checksum: "037af4ba6f25e45ebb5d7d08c88d008cd5c09f781d3af0fd972060e11cae7708" //SentryObjC-Static
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

let sentrySwiftTarget: Target = .target(
    name: "SentrySwift",
    dependencies: ["_SentryPrivate", "SentryHeaders"],
    path: "Sources/Swift",
    swiftSettings: [
        .unsafeFlags(["-enable-library-evolution"]),
        .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"])),
        .define("SDK_V10", .when(traits: ["V10"])),
        .define("SDK_V10", .when(traits: ["KSCrash"])),
        .define("ENABLE_KSCRASH", .when(traits: ["KSCrash"]))
    ]
)

if enableKSCrash {
    sentrySwiftTarget.dependencies.append(.product(name: "Installations", package: "KSCrash"))
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
            .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"])),
            .define("SDK_V10", to: "1", .when(traits: ["V10"])),
            .define("SDK_V10", to: "1", .when(traits: ["KSCrash"])),
            .define("ENABLE_KSCRASH", to: "1", .when(traits: ["KSCrash"]))
        ])
]

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat",
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"])),
            .define("SDK_V10", .when(traits: ["V10"])),
            .define("SDK_V10", .when(traits: ["KSCrash"])),
            .define("ENABLE_KSCRASH", .when(traits: ["KSCrash"]))
        ]
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"])),
            .define("SDK_V10", to: "1", .when(traits: ["V10"])),
            .define("SDK_V10", to: "1", .when(traits: ["KSCrash"])),
            .define("ENABLE_KSCRASH", to: "1", .when(traits: ["KSCrash"]))
        ]
    )
]
// END:OBJC_WRAPPER

let packageDependencies: [Package.Dependency] = enableKSCrash ? [.package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.6.0-beta.3")] : []

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit/SwiftUI framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable."),
        .init(name: "V10", description: "Enable SDK V10 API changes."),
        .init(name: "KSCrash", description: "Enable upstream KSCrash integration.")
    ],
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
