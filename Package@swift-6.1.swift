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
    "SentryCrash/Recording/Tools/SentryCrashCPU.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_arm.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_arm64.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_x86_32.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_x86_64.c",
    "SentryCrash/Recording/Tools/SentryCrashMachineContext.c",
    "SentryCrash/Recording/Tools/SentryCrashMemory.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_MachineContext.c",
    "SentryCrash/Recording/Tools/SentryCrashThread.c",
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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/Sentry.xcframework.zip",
            checksum: "843b01666de4e4a0e7a1574abdcd6823d878032ee6ed1c03304c8f289c59447d" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/Sentry-Dynamic.xcframework.zip",
            checksum: "ef92cd165b7141e4b712afea1a130589a4667b0c6202e0fe507b2496238fe4ba" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "32c0c6be2725ac3fa6881ac0a5366cfce6a93056b0544ff8df3e189ce8c003f7" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "099e3f072215aa839f7a2e45de3da6c752238c924d4875926fb9511a1934cb9a" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "b673f8f06c35669ca72916ac5e76a312833a9d9d4b69268ccc8a9fdb238fa513" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/SentryObjC-Dynamic.xcframework.zip",
            checksum: "96fea8f3cfbfae90dcf77512692f9eeec392254684bb72beb27ff9b7b73964b6" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.3/SentryObjC-Static.xcframework.zip",
            checksum: "3a5ad02b1ae27a1d1314edd2d6fce91757143a71433cc55af352aa6db4c32b93" //SentryObjC-Static
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
            name: "Recording",
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
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "391bf0a9569b6c1aa9df30b3fa4bcabbc0a07e7a")
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
