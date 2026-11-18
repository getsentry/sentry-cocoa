// swift-tools-version:6.0

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

let envSelectsV10 = envFlag("SDK_V10")
// Packaging changes the module name, never the SDK implementation or crash backend.
let buildXCFramework = envFlag("SENTRY_BUILD_XCFRAMEWORK")
let sourceUsesSentryModule = envSelectsV10 || buildXCFramework
let sentrySwiftTargetName = sourceUsesSentryModule ? "Sentry" : "SentrySwift"
let frameworkSwiftSettings: [SwiftSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK")] : []
let frameworkCSettings: [CSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
let frameworkCxxSettings: [CXXSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
let v10SwiftSettings: [SwiftSetting] = envSelectsV10 ? [.define("SDK_V10")] : []
let v10CSettings: [CSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let v10CxxSettings: [CXXSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let swiftSettings: [SwiftSetting] = [.define("SWIFT_PACKAGE")] + v10SwiftSettings + frameworkSwiftSettings
// SwiftPM's defaults do not reach Swift's Clang importer.
let cSettings: [CSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CSettings + frameworkCSettings
let cxxSettings: [CXXSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CxxSettings + frameworkCxxSettings

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

if !sourceUsesSentryModule {
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

var targets: [Target] = buildXCFramework ? [] : [
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

if !sourceUsesSentryModule {
    // BEGIN:BINARY_TARGETS
    targets += [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/Sentry.xcframework.zip",
            checksum: "6c460f79c18f8dc2c694f8367e2a5d5edb0e54e4f9a4cfe5ea6c7f9d21fc242b" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/Sentry-Dynamic.xcframework.zip",
            checksum: "a59b69fcdbe19a30f376d83b1f3a387d05d5b9ee6064d7f62d48b4a6320c6625" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "178ecdb61c62c31f48fdcb7220b39be3867a5fdd658808a97448d148bef80a8e" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "cd7222f60c96df5d80d2f92111a90eb97df27091f55e8da81963511e7dd323aa" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "58e287dc7592ba75f914cf975a4f147647934e1fb39b92c39dd82f40abb5a0d8" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "199980b6a7aed5fcba387c3fc47872710d24829af04fb5c90a291084f197e7ba" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.35.0/SentryObjC-Static.xcframework.zip",
            checksum: "04fd7b4dad0112611e7499bd1aa6a35c4d19bd1e24eabbcd45d4958b9bc499b0" //SentryObjC-Static
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
if sourceUsesSentryModule {
    products.append(.library(name: "Sentry", targets: ["SentryObjCInternal"]))
} else {
    products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
}
let sentrySwiftTarget: Target = .target(
    name: sentrySwiftTargetName,
    dependencies: ["_SentryPrivate", "SentryHeaders"],
    path: "Sources/Swift",
    cSettings: cSettings,
    swiftSettings: swiftSettings
)

if envSelectsV10 {
    sentrySwiftTarget.dependencies += [
        .product(name: "Recording", package: "KSCrash"),
        .product(name: "RecordingCore", package: "KSCrash")
    ]
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
    .headerSearchPath("Sentry")
] + cSettings

let sentryPrivateDependencies: [Target.Dependency] = if envSelectsV10 {
    ["SentryHeaders", .product(name: "Recording", package: "KSCrash")]
} else {
    ["SentryHeaders", "_SentryCrashV9Headers"]
}

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        dependencies: envSelectsV10 ? ["_SentryV10Configuration"] : [],
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
        cSettings: cSettings
    ),

    sentrySwiftTarget
]

var sentryObjCInternalDependencies: [Target.Dependency] = [.target(name: sentrySwiftTargetName)]
if envSelectsV10 {
    sentryObjCInternalDependencies.append(.product(name: "Recording", package: "KSCrash"))
} else {
    sentrySwiftTarget.dependencies.append("_SentryCrashV9Headers")
    sentryObjCInternalDependencies += ["SentryCrashV9", "_SentryCrashV9Headers"]
}

// Package-wide builds schedule every regular target, not only product dependencies.
// Keep both recorder targets out of the environment-selected V10 graph entirely.
if !envSelectsV10 {
    targets += [
        .target(
            name: "SentryCrashV9Swift",
            dependencies: [.target(name: sentrySwiftTargetName), "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
            path: "Sources/SentryCrashV9Swift",
            swiftSettings: frameworkSwiftSettings
        ),
        .target(
            name: "SentryCrashV9",
            dependencies: ["SentryCrashV9Swift", .target(name: sentrySwiftTargetName), "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
            path: "Sources",
            // Xcode discovers resources independently of sources; the recorder owns no SDK bundle.
            exclude: ["Resources"],
            sources: [
                "SentryCrash",
                "Sentry/SentryCrashDefaultMachineContextWrapper.m",
                "Sentry/SentryCrashReportSink.m",
                "Sentry/SentryCrashScopeObserver.m"
            ],
            publicHeadersPath: "SentryCrashV9Module/include",
            cSettings: [.headerSearchPath("Sentry")] + cSettings
        )
    ]
}

targets += [
    // SentryObjCInternal compiles reporter-neutral ObjC/C sources. The V9 recorder is isolated in
    // SentryCrashV9 so no V10 target graph schedules Sources/SentryCrash implementations.
    .target(
        name: "SentryObjCInternal",
        dependencies: sentryObjCInternalDependencies,
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
        swiftSettings: swiftSettings + objcCompatSwiftSettings
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ] + cSettings
    )
]
// END:OBJC_WRAPPER

targets += [
    .target(
        name: "SentryTestUtilsObjC",
        dependencies: ["SentryObjCInternal", .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
        path: "SentryTestUtils/SourcesObjC",
        // One fixture bundle shared by Swift and Clang tests. Copy preserves nested paths.
        resources: [
            .copy("../../Tests/Fixtures"),
            .copy("../../Tests/SentryTests/Helper/InfoPlist/TestInfoPlist.plist")
        ],
        cSettings: [
            .headerSearchPath("."),
            // Xcode's generated ObjC resource accessor has a non-prototype C function.
            .unsafeFlags(["-Wno-strict-prototypes"])
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
        cSettings: cSettings,
        cxxSettings: cxxSettings,
        linkerSettings: [
            // The profiler mocks use C++ standard-library types such as std::vector.
            .linkedLibrary("c++")
        ]
    ),
    .target(
        name: "SentryTestUtils",
        dependencies: [
            "SentryObjCInternal",
            .target(name: sentrySwiftTargetName),
            "_SentryPrivate",
            "SentryTestUtilsObjC",
            "SentryTestUtilsObjCpp"
        ],
        path: "SentryTestUtils/Sources",
        cSettings: cSettings,
        swiftSettings: swiftSettings
    ),
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: [.target(name: sentrySwiftTargetName), "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: cSettings,
        swiftSettings: swiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", .target(name: sentrySwiftTargetName), "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        cSettings: cSettings,
        swiftSettings: swiftSettings + objcCompatSwiftSettings
    )
]

// SwiftPM cannot mix Swift and Clang test sources in one target.
// Keep the main suite's existing language directories and V9/V10 source guards.
targets += [
    .testTarget(
        name: "SentryTests",
        dependencies: [
            .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp",
            .product(name: "SentryTestUtilsDynamic", package: "SentryTestUtilsDynamic", condition: .when(platforms: [.iOS, .macCatalyst, .tvOS, .visionOS]))
        ] + (envSelectsV10 ? [.product(name: "RecordingCore", package: "KSCrash")] : [.target(name: "SentryCrashV9Swift")]),
        path: "Tests/SentryTests",
        exclude: [
            "ObjC",
            "ObjCpp",
            "Info.plist",
            "Helper/InfoPlist/TestInfoPlist.plist",
            "OptionsInSyncWithDocs/README.md"
        ],
        cSettings: cSettings,
        swiftSettings: [
            .enableUpcomingFeature("BareSlashRegexLiterals")
        ] + swiftSettings
    )
]
targets += [
    .testTarget(
        name: "SentryTestsObjC",
        dependencies: ["SentryObjCInternal", .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC"],
        path: "Tests/SentryTests/ObjC",
        cSettings: cSettings
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
        cSettings: cSettings
    ),
    .testTarget(
        name: "SentryObjCTestsSwift",
        dependencies: ["SentryObjC", "SentryTestUtils"],
        path: "Tests/SentryObjCTests/Swift",
        cSettings: cSettings,
        swiftSettings: swiftSettings
    )
]

// Match the entire V9-only Xcode profiler suite, including its wrapper tests.
if !envSelectsV10 {
    targets += [
        .testTarget(
            name: "SentryProfilerTests",
            dependencies: [.target(name: sentrySwiftTargetName), "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests",
            exclude: ["ObjC"],
            cSettings: cSettings,
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SentryProfilerTestsObjC",
            dependencies: ["SentryObjCInternal", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests/ObjC",
            cSettings: [
                .headerSearchPath("../../../Sources/Sentry")
            ] + cSettings,
            // Xcode disables C++ modules for package test bundles by default. The ObjC++
            // tests import SentrySwift's generated Objective-C interface as a Clang module.
            cxxSettings: [.unsafeFlags(["-fmodules", "-fcxx-modules"])] + cxxSettings,
            linkerSettings: [.linkedLibrary("c++")]
        )
    ]
}

let packageDependencies: [Package.Dependency] = [
    // Test-only: keep this local dependency unreachable from all SDK products.
    .package(path: "SentryTestUtilsDynamic")
] + (envSelectsV10 ? [.package(url: "https://github.com/getsentry/KSCrash.git", revision: "e41302af9fbcf4d9cc6cc95933cb989a90941d37")] : [])

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: buildXCFramework ? xcframeworkProducts : products,
    dependencies: packageDependencies,
    targets: buildXCFramework ? xcframeworkTargets : targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
