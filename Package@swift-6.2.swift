// swift-tools-version:6.2

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
let v10SwiftSettings: [SwiftSetting] = enableV10
    ? [.define("SDK_V10")]
    : [.define("SDK_V10", .when(traits: ["V10"]))]
// Check backend selection in C/C++ and Swift's Clang imports, before importing V9 headers.
// The base manifest has no traits, so it deliberately does not set these validation markers.
let v10CSettings: [CSetting] = (enableV10
    ? [.define("SDK_V10", to: "1")]
    : [.define("SDK_V10", to: "1", .when(traits: ["V10"]))]) + [
        .define("SENTRY_SWIFTPM_BACKEND_TRAITS", to: "1"),
        .define("SENTRY_SWIFTPM_V9", to: "1", .when(traits: ["V9"])),
        .define("SENTRY_SWIFTPM_V10", to: "1", .when(traits: ["V10"]))
    ]
// PackageDescription uses distinct C and C++ setting types, so this cannot reuse v10CSettings.
let v10CxxSettings: [CXXSetting] = (enableV10
    ? [.define("SDK_V10", to: "1")]
    : [.define("SDK_V10", to: "1", .when(traits: ["V10"]))]) + [
        .define("SENTRY_SWIFTPM_BACKEND_TRAITS", to: "1"),
        .define("SENTRY_SWIFTPM_V9", to: "1", .when(traits: ["V9"])),
        .define("SENTRY_SWIFTPM_V10", to: "1", .when(traits: ["V10"]))
    ]
let kscrashDependencyCondition: TargetDependencyCondition? = enableV10
    ? nil
    : .when(traits: ["V10"])

// Match the wrapper targets' compiler settings in Sentry.xcodeproj.
let objcCompatSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/Sentry.xcframework.zip",
            checksum: "8d54d420474afdf6bee4ca060b8edbbd8948798d635ce7a9b477d884094b16b0" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/Sentry-Dynamic.xcframework.zip",
            checksum: "2a4c9e902c9f8fe97561669f7f6282ac23c64b6bf4c0500aee22948e4a8c8daa" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "dcd7df50d1b4b31d95efa69c224797b334639a963f440a06868bc0d246d09172" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "38799c096e2c5449157d93ed4ab51f1d6219e73a8fa4ca5bed6f4f26d137424e" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "5c751b9b7b775dfb3086bb3a942ea2b4e7d43fd54c773df2670b7c98aff02ac7" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/SentryObjC-Dynamic.xcframework.zip",
            checksum: "f756942f391070c4e01e956095cdc4ca2e9dc7d7bd00c6cc2ecbd2aea37e01e0" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.2/SentryObjC-Static.xcframework.zip",
            checksum: "ba8d59d8ba44e65a3c263f94955dbf0c8cc12890a553fdbb19d894aa01c34500" //SentryObjC-Static
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
    cSettings: v10CSettings,
    swiftSettings: [
        .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
    ] + v10SwiftSettings
)
if !enableV10 {
    sentrySwiftTarget.dependencies.append(
        .target(name: "_SentryCrashV9Headers", condition: .when(traits: ["V9"]))
    )
}

let sentryObjCInternalExcludes = [
    "Sentry/SentryDummyPublicEmptyClass.m",
    "Sentry/SentryDummyPrivateEmptyClass.m",
    "Sentry/SentryCrashDefaultMachineContextWrapper.m",
    "Sentry/SentryCrashReportSink.m",
    "Sentry/SentryCrashScopeObserver.m",
    "SentryCrash",
    "SentryCrashV9Headers",
    "SentryCrashV9Module",
    "SentryCrashV9Swift",
    "SentryV10Configuration",
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

let sentryObjCInternalCSettings: [CSetting] = [
    .headerSearchPath("Sentry"),
    .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"])),
    .define("SENTRY_UI_TEST_SUPPORT", to: "1", .when(traits: ["_SentryInternalUITestSupport"]))
] + v10CSettings

var sentryPrivateDependencies: [Target.Dependency] = [
    "SentryHeaders",
    .product(
        name: "Recording",
        package: "KSCrash",
        condition: kscrashDependencyCondition
    )
]
if !enableV10 {
    sentryPrivateDependencies.append(
        .target(name: "_SentryCrashV9Headers", condition: .when(traits: ["V9"]))
    )
}

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        dependencies: [.target(name: "_SentryV10Configuration", condition: kscrashDependencyCondition)],
        path: "Sources/Sentry",
        sources: ["SentryDummyPublicEmptyClass.m"],
        publicHeadersPath: "Public",
        cSettings: v10CSettings
    ),
    .target(
        name: "_SentryV10Configuration",
        path: "Sources/SentryV10Configuration",
        publicHeadersPath: "include"
    ),
    .target(
        name: "_SentryCrashV9Headers",
        path: "Sources/SentryCrashV9Headers",
        publicHeadersPath: "include"
    ),
    .target(
        name: "_SentryPrivate",
        dependencies: sentryPrivateDependencies,
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include",
        cSettings: v10CSettings
    ),

    sentrySwiftTarget,
    .target(
        name: "SentryCrashV9Swift",
        dependencies: ["SentrySwift", "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
        path: "Sources/SentryCrashV9Swift",
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ]
    )
]

var sentryObjCInternalDependencies: [Target.Dependency] = [
    "SentrySwift",
    .product(
        name: "Recording",
        package: "KSCrash",
        condition: kscrashDependencyCondition
    )
]
if !enableV10 {
    sentryObjCInternalDependencies += [
        .target(name: "SentryCrashV9", condition: .when(traits: ["V9"])),
        .target(name: "_SentryCrashV9Headers", condition: .when(traits: ["V9"]))
    ]
}

targets += [
    .target(
        name: "SentryCrashV9",
        dependencies: ["SentryCrashV9Swift", "SentrySwift", "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
        path: "Sources",
        sources: [
            "SentryCrash",
            "Sentry/SentryCrashDefaultMachineContextWrapper.m",
            "Sentry/SentryCrashReportSink.m",
            "Sentry/SentryCrashScopeObserver.m"
        ],
        publicHeadersPath: "SentryCrashV9Module/include",
        cSettings: [.headerSearchPath("Sentry")]
    ),
    // SentryObjCInternal compiles reporter-neutral ObjC/C sources. The V9 recorder is isolated in
    // SentryCrashV9 so no V10 target graph schedules Sources/SentryCrash implementations.
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
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
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
        cSettings: v10CSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings
    ),
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: v10CSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        cSettings: v10CSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings + objcCompatSwiftSettings
    )
]

// Match the entire V9-only Xcode profiler suite, including its wrapper tests.
// Traits cannot remove targets, so source guards also exclude this suite when V10 is selected.
if !enableV10 {
    targets += [
        .testTarget(
            name: "SentryProfilerTests",
            dependencies: ["SentrySwift", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests",
            exclude: ["ObjC"],
            swiftSettings: v10SwiftSettings
        ),
        .testTarget(
            name: "SentryProfilerTestsObjC",
            dependencies: ["SentryObjCInternal", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests/ObjC",
            cSettings: [
                .headerSearchPath("../../../Sources/Sentry")
            ] + v10CSettings,
            // Xcode disables C++ modules for package test bundles by default. The ObjC++
            // tests import SentrySwift's generated Objective-C interface as a Clang module.
            cxxSettings: [.unsafeFlags(["-fcxx-modules"])] + v10CxxSettings,
            linkerSettings: [.linkedLibrary("c++")]
        )
    ]
}

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
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "18a633dec20c265f03386294f9d82d208bb13094")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    traits: [
        .default(enabledTraits: ["V9"]),
        .init(name: "V9", description: "Build the default SentryCrash-backed SDK."),
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
