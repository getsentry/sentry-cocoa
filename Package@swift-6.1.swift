// swift-tools-version:6.1

// Package targets and build settings must stay in a single manifest.
// swiftlint:disable file_length

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

let enableV10 = envFlag("SDK_V10")
// SwiftPM has no source include override; CI audits this complement against the Xcode allowlist.
let v10ExcludedSentryCrashToolSources = [
    "SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.c",
    "SentryCrash/Recording/Tools/SentryCrashDate.c",
    "SentryCrash/Recording/Tools/SentryCrashDebug.c",
    "SentryCrash/Recording/Tools/SentryCrashDynamicLinker.c",
    "SentryCrash/Recording/Tools/SentryCrashFileUtils.c",
    "SentryCrash/Recording/Tools/SentryCrashID.c",
    "SentryCrash/Recording/Tools/SentryCrashJSONCodec.c",
    "SentryCrash/Recording/Tools/SentryCrashJSONCodecObjC.m",
    "SentryCrash/Recording/Tools/SentryCrashMach-O.c",
    "SentryCrash/Recording/Tools/SentryCrashMach.c",
    "SentryCrash/Recording/Tools/SentryCrashNSErrorUtil.m",
    "SentryCrash/Recording/Tools/SentryCrashObjC.c",
    "SentryCrash/Recording/Tools/SentryCrashSignalInfo.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_Backtrace.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_SelfThread.m",
    "SentryCrash/Recording/Tools/SentryCrashString.c",
    "SentryCrash/Recording/Tools/SentryCrashSysCtl.c",
    "SentryCrash/Recording/Tools/SentryCrashUUIDConversion.c"
]
let v10SwiftSettings: [SwiftSetting] = enableV10
    ? [.define("SDK_V10"), .define("SENTRY_DISABLE_SENTRYCRASH_V10")]
    : [
        .define("SDK_V10", .when(traits: ["V10"])),
        .define("SENTRY_DISABLE_SENTRYCRASH_V10", .when(traits: ["V10"]))
    ]
let v10CSettings: [CSetting] = enableV10
    ? [.define("SDK_V10", to: "1"), .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1")]
    : [
        .define("SDK_V10", to: "1", .when(traits: ["V10"])),
        .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1", .when(traits: ["V10"]))
    ]
// PackageDescription uses distinct C and C++ setting types, so this cannot reuse v10CSettings.
let v10CxxSettings: [CXXSetting] = enableV10
    ? [.define("SDK_V10", to: "1"), .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1")]
    : [
        .define("SDK_V10", to: "1", .when(traits: ["V10"])),
        .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1", .when(traits: ["V10"]))
    ]
let kscrashDependencyCondition: TargetDependencyCondition? = enableV10
    ? nil
    : .when(traits: ["V10"])

// Match the wrapper targets' compiler settings in Sentry.xcodeproj.
var objcCompatSwiftSettings: [SwiftSetting] = []
#if compiler(>=6.1)
objcCompatSwiftSettings.append(.enableUpcomingFeature("MemberImportVisibility"))
#endif

// Older Xcodes ignore approachable concurrency. Some individual features already exist in
// older compilers, so gate the group to avoid enabling a subset that the project does not.
#if compiler(>=6.2)
objcCompatSwiftSettings += [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]
#endif

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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/Sentry.xcframework.zip",
            checksum: "0c5caf36bb129b8ca1b258bd7d455c451eefb517acd01c0347f35723afbc1473" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/Sentry-Dynamic.xcframework.zip",
            checksum: "f1a8073292675bbdfbd093cc6eac9ca0f66de78c5ea7804b1b5a9ac1d0cc84f9" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "0016eacab9e64ea1741ac93a4cb182b3a030c6d47323e56bfb84ef24073b0306" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "bcef3b10e0e4bd6e076bfc7639bcdf3b6f750ea48adb4a05b0cb921eb80d6f17" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "147388f6fbe7df724aa336a34e9414c05f79c0f84f5772695796dd8851c8910a" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "5add51d7926b560d0475ee4ad2e387bb05de2b68bc08a2fcf8cf841bcdb773ce" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.28.0/SentryObjC-Static.xcframework.zip",
            checksum: "457a7643c6effdcc4773c2c862343a9b956a147e9b9fe70f5acc2e6fe46c06d4" //SentryObjC-Static
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

let sentrySwiftExcludes = enableV10 ? [
    "Integrations/SentryCrash",
    "SentryCrash/SentryCrashSwift.swift",
    "SentryCrash/SentryDefaultCrashReporter.swift"
] : []

let sentrySwiftTarget: Target = .target(
    name: "SentrySwift",
    dependencies: [
        "_SentryPrivate",
        "SentryHeaders",
        .product(
            name: "Installations",
            package: "KSCrash",
            condition: kscrashDependencyCondition
        ),
        .product(
            name: "RecordingCore",
            package: "KSCrash",
            condition: kscrashDependencyCondition
        )
    ],
    path: "Sources/Swift",
    exclude: sentrySwiftExcludes,
    cSettings: v10CSettings,
    swiftSettings: [
        .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
    ] + v10SwiftSettings
)

var sentryObjCInternalExcludes = [
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
]

if enableV10 {
    sentryObjCInternalExcludes += v10ExcludedSentryCrashToolSources + [
        "Sentry/SentryCrashReportSink.m",
        "Sentry/SentryCrashScopeObserver.m",
        "SentryCrash/Installations",
        "SentryCrash/Reporting",
        "SentryCrash/Recording/Monitors",
        "SentryCrash/Recording/SentryCrash.m",
        "SentryCrash/Recording/SentryCrashBinaryImageCache.c",
        "SentryCrash/Recording/SentryCrashBinaryImageCacheState.h",
        "SentryCrash/Recording/SentryCrashC.c",
        "SentryCrash/Recording/SentryCrashCachedData.c",
        "SentryCrash/Recording/SentryCrashCachedData.h",
        "SentryCrash/Recording/SentryCrashDoctor.h",
        "SentryCrash/Recording/SentryCrashDoctor.m",
        "SentryCrash/Recording/SentryCrashReport.c",
        "SentryCrash/Recording/SentryCrashReport.h",
        "SentryCrash/Recording/SentryCrashReportFields.h",
        "SentryCrash/Recording/SentryCrashReportFixer.c",
        "SentryCrash/Recording/SentryCrashReportFixer.h",
        "SentryCrash/Recording/SentryCrashReportStore.c",
        "SentryCrash/Recording/SentryCrashReportStore.h",
        "SentryCrash/Recording/SentryCrashReportVersion.h",
        "SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.h",
        "SentryCrash/Recording/Tools/SentryCrashSysCtl.h"
    ]
}

let sentryObjCInternalCSettings: [CSetting] = [
    .headerSearchPath("Sentry"),
    .headerSearchPath("SentryCrash/Recording"),
    .headerSearchPath("SentryCrash/Recording/Monitors"),
    .headerSearchPath("SentryCrash/Recording/Tools"),
    .headerSearchPath("SentryCrash/Installations"),
    .headerSearchPath("SentryCrash/Reporting/Filters"),
    .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
    .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"])),
    .define("SENTRY_UI_TEST_SUPPORT", to: "1", .when(traits: ["_SentryInternalUITestSupport"]))
] + v10CSettings

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        path: "Sources/Sentry",
        sources: ["SentryDummyPublicEmptyClass.m"],
        publicHeadersPath: "Public",
        cSettings: v10CSettings
    ),
    .target(
        name: "_SentryPrivate",
        dependencies: [
            "SentryHeaders",
            .product(
                name: "Recording",
                package: "KSCrash",
                condition: kscrashDependencyCondition
            )
        ],
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include",
        cSettings: v10CSettings
    ),

    sentrySwiftTarget
]

var sentryObjCInternalDependencies: [Target.Dependency] = ["SentrySwift"]
sentryObjCInternalDependencies.append(.product(
    name: "Recording",
    package: "KSCrash",
    condition: kscrashDependencyCondition
))

targets += [
    // SentryObjCInternal compiles all ObjC/C sources from the repo. Named "Internal"
    // to reserve "SentryObjC" for a future public Objective-C wrapper around the SDK.
    .target(
        name: "SentryObjCInternal",
        dependencies: sentryObjCInternalDependencies,
        path: "Sources",
        exclude: sentryObjCInternalExcludes,
        cSettings: sentryObjCInternalCSettings)
]

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat",
        cSettings: v10CSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings + objcCompatSwiftSettings
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + v10CSettings
    )
]
// END:OBJC_WRAPPER

// Swift 6.1 needs smaller expressions to type-check the test targets.
targets += [
    .target(
        name: "SentryTestUtilsObjC",
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders"],
        path: "SentryTestUtils/SourcesObjC",
        publicHeadersPath: "include",
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + v10CSettings
    ),
    .target(
        name: "SentryTestUtilsObjCpp",
        dependencies: ["SentryObjCInternal", "_SentryPrivate"],
        path: "SentryTestUtils/SourcesObjCpp",
        publicHeadersPath: ".",
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + v10CSettings,
        cxxSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + v10CxxSettings,
        linkerSettings: [
            // The profiler mocks use C++ standard-library types such as std::vector.
            .linkedLibrary("c++")
        ]
    )
]
targets += [
    .target(
        name: "SentryTestUtils",
        dependencies: [
            "SentryObjCInternal",
            "SentrySwift",
            "_SentryPrivate",
            "SentryTestUtilsObjC",
            "SentryTestUtilsObjCpp"
        ],
        path: "SentryTestUtils/Sources",
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings
    )
]

// Separate test declarations to stay within Swift 6.1's type-checking budget.
targets += [
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings + objcCompatSwiftSettings
    )
]

// Match SDK.xcconfig's Test/TestCI defines on source/test targets, including Swift's Clang importer.
for target in targets where target.type == .regular || target.type == .test {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .define("SENTRY_TEST", .when(traits: ["_SentryTest"])),
        .define("SENTRY_TEST_CI", .when(traits: ["_SentryTestCI"]))
    ]
    target.cSettings = (target.cSettings ?? []) + [
        .define("DEBUG", to: "1", .when(traits: ["_SentryTest", "_SentryTestCI"])),
        .define("SENTRY_TEST", to: "1", .when(traits: ["_SentryTest", "_SentryTestCI"])),
        .define("SENTRY_TEST_CI", to: "1", .when(traits: ["_SentryTestCI"]))
    ]
    target.cxxSettings = (target.cxxSettings ?? []) + [
        .define("DEBUG", to: "1", .when(traits: ["_SentryTest", "_SentryTestCI"])),
        .define("SENTRY_TEST", to: "1", .when(traits: ["_SentryTest", "_SentryTestCI"])),
        .define("SENTRY_TEST_CI", to: "1", .when(traits: ["_SentryTestCI"]))
    ]
}

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.6.0")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit/SwiftUI framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable."),
        .init(name: "V10", description: "Enable SDK V10 API changes, including the upstream KSCrash integration."),
        .init(name: "_SentryInternalUITestSupport", description: "Internal support for Sentry's sample UI tests. Do not enable in production."),
        .init(name: "_SentryTest", description: "Internal SDK unit-test support for local development. Changes SDK behavior; not for consumers or production builds."),
        .init(name: "_SentryTestCI", description: "Internal SDK unit-test support for CI. Changes SDK behavior; not for consumers or production builds.")
    ],
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
