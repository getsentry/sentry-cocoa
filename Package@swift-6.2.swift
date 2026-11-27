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

// Packaging builds only the main SDK graph, never a different SDK implementation.
let buildXCFramework = envFlag("SENTRY_BUILD_XCFRAMEWORK")
let frameworkSwiftSettings: [SwiftSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK")] : []
let frameworkCSettings: [CSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
let frameworkCxxSettings: [CXXSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
// Sources still carry SDK_V10 guards, so the package always defines it.
let swiftSettings: [SwiftSetting] = [.define("SWIFT_PACKAGE"), .define("SDK_V10")] + frameworkSwiftSettings
// SwiftPM's defaults do not reach Swift's Clang importer.
let cSettings: [CSetting] = [.define("SWIFT_PACKAGE", to: "1"), .define("SDK_V10", to: "1")] + frameworkCSettings
let cxxSettings: [CXXSetting] = [.define("SWIFT_PACKAGE", to: "1"), .define("SDK_V10", to: "1")] + frameworkCxxSettings

// Match the wrapper targets' compiler settings in Sentry.xcodeproj.
let objcCompatSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

var products: [Product] = buildXCFramework ? [] : [
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

var targets: [Target] = buildXCFramework ? [] : [
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

products.append(.library(name: "Sentry", targets: ["SentryObjCInternal"]))

// Sources is one directory tree, so every sibling that SentryObjCInternal must not compile is
// listed here. The crash-recorder entries can go once those sources are deleted.
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
] + cSettings

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        dependencies: ["_SentryV10Configuration"],
        path: "Sources/Sentry",
        sources: ["SentryDummyPublicEmptyClass.m"],
        publicHeadersPath: "Public",
        cSettings: cSettings
    ),
    .target(
        name: "_SentryV10Configuration",
        path: "Sources/SentryV10Configuration",
        publicHeadersPath: "include"
    ),
    .target(
        name: "_SentryPrivate",
        dependencies: ["SentryHeaders", .product(name: "Recording", package: "KSCrash")],
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include",
        cSettings: cSettings
    )
]

targets += [
    .target(
        name: "Sentry",
        dependencies: [
            "_SentryPrivate",
            "SentryHeaders",
            .product(name: "Recording", package: "KSCrash"),
            .product(name: "RecordingCore", package: "KSCrash")
        ],
        path: "Sources/Swift",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    ),
    .target(
        name: "SentryObjCInternal",
        dependencies: [.target(name: "Sentry"), .product(name: "Recording", package: "KSCrash")],
        path: "Sources",
        exclude: sentryObjCInternalExcludes,
        cSettings: sentryObjCInternalCSettings)
]

// Packaging builds only the main SDK. Keep wrapper and test source graphs unchanged;
// they are not part of this XCFramework and retain ordinary source-module imports.
let xcframeworkProducts = products
let xcframeworkTargets = targets

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings + objcCompatSwiftSettings
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public"),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings
    )
]
// END:OBJC_WRAPPER

// Swift 6.1 needs smaller expressions to type-check the test targets.
targets += [
    .target(
        name: "SentryTestUtilsObjC",
        dependencies: ["SentryObjCInternal", .target(name: "Sentry"), "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
        path: "SentryTestUtils/SourcesObjC",
        // One fixture bundle shared by Swift and Clang tests. Copy preserves nested paths.
        resources: [
            .copy("../../Tests/Fixtures"),
            .copy("../../Tests/SentryTests/Helper/InfoPlist/TestInfoPlist.plist")
        ],
        cSettings: [
            .headerSearchPath("."),
            // Xcode's generated ObjC resource accessor has a non-prototype C function.
            .unsafeFlags(["-Wno-strict-prototypes"]),
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings,
        linkerSettings: [
            .linkedLibrary("z"),
            // Equality categories have no referenced symbols to pull them out of a static archive.
            .unsafeFlags(["-Xlinker", "-ObjC"])
        ]
    ),
    .target(
        name: "SentryTestUtilsObjCpp",
        dependencies: ["SentryObjCInternal", "_SentryPrivate"],
        path: "SentryTestUtils/SourcesObjCpp",
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings,
        cxxSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cxxSettings,
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
            .target(name: "Sentry"),
            "_SentryPrivate",
            "SentryTestUtilsObjC",
            "SentryTestUtilsObjCpp"
        ],
        path: "SentryTestUtils/Sources",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    ),
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: [.target(name: "Sentry"), "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", .target(name: "Sentry"), "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings + objcCompatSwiftSettings
    )
]

// SwiftPM cannot mix Swift and Clang test sources in one target.
// Keep the main suite's existing language directories and V9/V10 source guards.
targets += [
    .testTarget(
        name: "SentryTests",
        dependencies: [
            .target(name: "Sentry"), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp",
            .product(name: "SentryTestUtilsDynamic", package: "SentryTestUtilsDynamic", condition: .when(platforms: [.iOS, .macCatalyst, .tvOS, .visionOS])),
            .product(name: "RecordingCore", package: "KSCrash")
        ],
        path: "Tests/SentryTests",
        exclude: [
            "ObjC",
            "ObjCpp",
            "Info.plist",
            "Helper/InfoPlist/TestInfoPlist.plist",
            "OptionsInSyncWithDocs/README.md"
        ],
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings,
        swiftSettings: [
            .enableUpcomingFeature("BareSlashRegexLiterals"),
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    )
]
targets += [
    .testTarget(
        name: "SentryTestsObjC",
        dependencies: ["SentryObjCInternal", .target(name: "Sentry"), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC"],
        path: "Tests/SentryTests/ObjC",
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings
    ),
    .testTarget(
        name: "SentryTestsObjCpp",
        dependencies: ["SentryObjCInternal", "_SentryPrivate", "SentryTestUtilsObjCpp"],
        path: "Tests/SentryTests/ObjCpp",
        cxxSettings: cxxSettings,
        linkerSettings: [.linkedLibrary("c++")]
    )
]

// Public API tests exercise the hand-written ObjC headers, not the Swift compat implementation.
targets += [
    .testTarget(
        name: "SentryObjCTests",
        dependencies: ["SentryObjC"],
        path: "Tests/SentryObjCTests",
        exclude: ["Swift"],
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings
    ),
    .testTarget(
        name: "SentryObjCTestsSwift",
        dependencies: ["SentryObjC", "SentryTestUtils"],
        path: "Tests/SentryObjCTests/Swift",
        cSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
        ] + cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    )
]

let packageDependencies: [Package.Dependency] = [
    // Test-only: keep this local dependency unreachable from all SDK products.
    .package(
        path: "SentryTestUtilsDynamic",
        traits: [.trait(name: "NoUIFramework", condition: .when(traits: ["NoUIFramework"]))]
    ),
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "c00af21aabcd2f84983abdcb2063c9446a524e74")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: buildXCFramework ? xcframeworkProducts : products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit/SwiftUI framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable."),
        .init(name: "_SentryInternalUITestSupport", description: "Internal support for Sentry's sample UI tests. Do not enable in production.")
    ],
    dependencies: packageDependencies,
    targets: buildXCFramework ? xcframeworkTargets : targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
