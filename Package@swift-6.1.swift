// swift-tools-version:6.1

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
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/Sentry.xcframework.zip",
        checksum: "d6d545af17e49851cda2747b0f45cde78ce08ea37709dde5a956c6b4671224e8" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/Sentry-Dynamic.xcframework.zip",
        checksum: "7d0fb876a35b40ef942d36cd43dcab0ee16d2874d5cc7cc668e8e01e0c83db2a" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "bb8c4cd4f622decc0fa3bf5c30cb0b793c123647a54f3da3c4afc3e0437443b7" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "3031ef708f89b44e410bdd5d868ad87b0a19a42f7605c37732542b8ebaae3d77" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "5eaee01cefe3f056d4763b6931ac4b61b3cdccb53899edfb875ea77c6f1e5fd8" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .binaryTarget(
        name: "SentryObjC-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/SentryObjC-Dynamic.xcframework.zip",
        checksum: "87079d0f1c2a0f0c69bc897775d2a4d24f8e5e29fab7616b45023c7b3fe4ac0c" //SentryObjC-Dynamic
    ),
    .binaryTarget(
        name: "SentryObjC-Static",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.19.1/SentryObjC-Static.xcframework.zip",
        checksum: "c656d347b29072b2d19a0f6ae6b43c9a1414f6c06025c370951cd94728d48244" //SentryObjC-Static
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
