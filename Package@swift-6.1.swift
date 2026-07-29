// swift-tools-version:6.1

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

func envFlag(_ name: String) -> Bool {
    getenv(name).map { String(cString: $0) == "1" } ?? false
}

let enableKSCrash = envFlag("ENABLE_KSCRASH")
let enableV10 = envFlag("SDK_V10")

var products: [Product] = [
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

if !enableV10 {
    // BEGIN:BINARY_PRODUCTS
    products += [
        .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
        .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
        .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
        .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
        .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
        .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
        .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"]),
        .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"])
    ]
    // END:BINARY_PRODUCTS
}

var targets: [Target] = [
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

if !enableV10 {
    // BEGIN:BINARY_TARGETS
    targets += [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry.xcframework.zip",
            checksum: "8e5fbdffbb3f001849932c9bd605489271450e0f9d2ba9c4b438b060f5aab30b" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry-Dynamic.xcframework.zip",
            checksum: "ba5c2b8d28262ce5d93260f676efd532ee9ed30d7839b0dca013d71e4533d89b" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "5420f00176e56db5654e10a464d0370954d38f694b612699992923cc9b605de8" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "2c58e9163fab2217945f92703a401e855a071947afdecff1f8c898ee2c412380" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "dbd2046d6152432a8496a463e5819e1b669a65a54f0a2e87248fcd8cb1f92605" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/SentryObjC-Dynamic.xcframework.zip",
            checksum: "69b82f605c3344bd431192f28fe92dadd49aa15da377385ada9bbee3a7ea6df1" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/SentryObjC-Static.xcframework.zip",
            checksum: "3371ea1f4ccde1e01b8476791bc0911062aa12bf7c6d5b2eac621595bc35c66f" //SentryObjC-Static
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
        )
    ]
    // END:BINARY_TARGETS
}

// Targets required to support compile-from-source builds via SPM.
if enableV10 {
    products.append(.library(name: "Sentry", targets: ["SentryObjCInternal"]))
} else {
    products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
}

let sentrySwiftTarget: Target = .target(
    name: "SentrySwift",
    dependencies: ["_SentryPrivate", "SentryHeaders"],
    path: "Sources/Swift",
    swiftSettings: [
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
