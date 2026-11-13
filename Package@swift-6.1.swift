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

let envSelectsV10 = envFlag("SDK_V10")
// Packaging changes the module name, never the SDK implementation or crash backend.
let buildXCFramework = envFlag("SENTRY_BUILD_XCFRAMEWORK")
let sourceUsesSentryModule = envSelectsV10 || buildXCFramework
let sentrySwiftTargetName = sourceUsesSentryModule ? "Sentry" : "SentrySwift"
let frameworkSwiftSettings: [SwiftSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK")] : []
let frameworkCSettings: [CSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
let frameworkCxxSettings: [CXXSetting] = buildXCFramework ? [.define("SENTRY_BUILD_XCFRAMEWORK", to: "1")] : []
// Xcode 16.4 can expose inactive trait-conditioned configuration targets. Keep V9's
// graph deterministic here; older-toolchain V10 development uses SDK_V10=1 instead.
let v10SwiftSettings: [SwiftSetting] = envSelectsV10 ? [.define("SDK_V10")] : []
let v10CSettings: [CSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let v10CxxSettings: [CXXSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let kscrashDependencies: [Target.Dependency] = envSelectsV10
    ? [.product(name: "Recording", package: "KSCrash")]
    : []
let kscrashSwiftDependencies: [Target.Dependency] = kscrashDependencies + (envSelectsV10
    ? [.product(name: "RecordingCore", package: "KSCrash")]
    : [])
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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/Sentry.xcframework.zip",
            checksum: "1ee80dfb1bd94295f419a7a026467ce35a68143fb8da9f5e672264546b8f7c0d" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/Sentry-Dynamic.xcframework.zip",
            checksum: "f42e2666385309b848465d4748cd1bc8f25c1a717cba94325a956f9844bd6195" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "c67629e5af2eed517ea6e41f77352caedb5c59cbeb656eb120d84d38fce5d133" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "eb6f74764ab38df32de3233556e94d562d390862eaafa3ab5bbb2a79ba4b59d9" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "bc53608c10ec6905343c830fda41fec34440ec758d54b43770633b0425fb3b37" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "17f5bd5c58bfde6531cbbbd1fbe49ecd036735a8b8088ddc09077e9bf494ae6e" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.34.0/SentryObjC-Static.xcframework.zip",
            checksum: "bdb0f88a7a7728a4af0948ca9a689582d2fc1baecdb8a9953edd9125711a3f49" //SentryObjC-Static
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
    dependencies: [
        "_SentryPrivate",
        "SentryHeaders"
    ] + kscrashSwiftDependencies,
    path: "Sources/Swift",
    cSettings: cSettings,
    swiftSettings: [
        .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
    ] + swiftSettings
)
if !envSelectsV10 {
    sentrySwiftTarget.dependencies.append(
        .target(name: "_SentryCrashV9Headers")
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
] + cSettings

var sentryPrivateDependencies: [Target.Dependency] = ["SentryHeaders"] + kscrashDependencies
if !envSelectsV10 {
    sentryPrivateDependencies.append(
        .target(name: "_SentryCrashV9Headers")
    )
}

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        dependencies: envSelectsV10 ? [.target(name: "_SentryV10Configuration")] : [],
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

var sentryObjCInternalDependencies: [Target.Dependency] = [.target(name: sentrySwiftTargetName)] + kscrashDependencies
if !envSelectsV10 {
    sentryObjCInternalDependencies += [
        .target(name: "SentryCrashV9"),
        .target(name: "_SentryCrashV9Headers")
    ]
}

// Package-wide builds schedule every regular target, not only product dependencies.
// Keep both recorder targets out of the environment-selected V10 graph entirely.
if !envSelectsV10 {
    targets += [
        .target(
            name: "SentryCrashV9Swift",
            dependencies: [.target(name: sentrySwiftTargetName), "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
            path: "Sources/SentryCrashV9Swift",
            cSettings: v10CSettings,
            swiftSettings: [
                .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
            ] + v10SwiftSettings + frameworkSwiftSettings
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
            cSettings: [
                .headerSearchPath("Sentry"),
                .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
            ] + cSettings
        )
    ]
}

targets += [
    // The recorder stays separate from reporter-neutral SDK code; environment V10 excludes it.
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
        dependencies: ["SentryObjCInternal", .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
        path: "SentryTestUtils/SourcesObjC",
        // One fixture bundle shared by Swift and Clang tests. Copy preserves nested paths.
        resources: [
            .copy("../../Tests/Resources"),
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
            .target(name: sentrySwiftTargetName),
            "_SentryPrivate",
            "SentryTestUtilsObjC",
            "SentryTestUtilsObjCpp"
        ],
        path: "SentryTestUtils/Sources",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    )
]

// Separate test declarations to stay within Swift 6.1's type-checking budget.
targets += [
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: [.target(name: sentrySwiftTargetName), "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", .target(name: sentrySwiftTargetName), "SentryTestUtils"],
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
            .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp",
            .product(name: "SentryTestUtilsDynamic", package: "SentryTestUtilsDynamic", condition: .when(platforms: [.iOS, .tvOS, .visionOS]))
        ] + (envSelectsV10 ? [] : [.target(name: "SentryCrashV9Swift")]),
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
        dependencies: ["SentryObjCInternal", .target(name: sentrySwiftTargetName), "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC"],
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

// Match the entire V9-only Xcode profiler suite, including its wrapper tests.
// Environment V10 excludes the V9-only profiler suite.
if !envSelectsV10 {
    targets += [
        .testTarget(
            name: "SentryProfilerTests",
            dependencies: [.target(name: sentrySwiftTargetName), "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests",
            exclude: ["ObjC"],
            // Keep Swift's Clang importer consistent with the NoUI SDK declarations.
            cSettings: [
                .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
            ] + cSettings,
            swiftSettings: [
                .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
            ] + swiftSettings
        ),
        .testTarget(
            name: "SentryProfilerTestsObjC",
            dependencies: ["SentryObjCInternal", "SentryTestUtilsObjCpp"],
            path: "Tests/SentryProfilerTests/ObjC",
            cSettings: [
                .headerSearchPath("../../../Sources/Sentry"),
                .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
            ] + cSettings,
            // Xcode disables C++ modules for package test bundles by default. The ObjC++
            // tests import SentrySwift's generated Objective-C interface as a Clang module.
            cxxSettings: [
                .unsafeFlags(["-fmodules", "-fcxx-modules"]),
                .define("SENTRY_NO_UI_FRAMEWORK", to: "1", .when(traits: ["NoUIFramework"]))
            ] + cxxSettings,
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
    // Test-only: keep this local dependency unreachable from all SDK products.
    .package(
        path: "SentryTestUtilsDynamic",
        traits: [.trait(name: "NoUIFramework", condition: .when(traits: ["NoUIFramework"]))]
    ),
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "e41302af9fbcf4d9cc6cc95933cb989a90941d37")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: buildXCFramework ? xcframeworkProducts : products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit/SwiftUI framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable."),
        .init(name: "_SentryInternalUITestSupport", description: "Internal support for Sentry's sample UI tests. Do not enable in production."),
        .init(name: "_SentryTest", description: "Internal SDK unit-test support for local development. Changes SDK behavior; not for consumers or production builds."),
        .init(name: "_SentryTestCI", description: "Internal SDK unit-test support for CI. Changes SDK behavior; not for consumers or production builds.")
    ],
    dependencies: packageDependencies,
    targets: buildXCFramework ? xcframeworkTargets : targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
