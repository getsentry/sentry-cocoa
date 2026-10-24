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

let envSelectsV10 = envFlag("SDK_V10")
let v10SwiftSettings: [SwiftSetting] = envSelectsV10
    ? [.define("SDK_V10")]
    : [.define("SDK_V10", .when(traits: ["V10"]))]
let v10CSettings: [CSetting] = envSelectsV10
    ? [.define("SDK_V10", to: "1")]
    : [.define("SDK_V10", to: "1", .when(traits: ["V10"]))]
// PackageDescription uses distinct C and C++ setting types, so this cannot reuse v10CSettings.
let v10CxxSettings: [CXXSetting] = envSelectsV10
    ? [.define("SDK_V10", to: "1")]
    : [.define("SDK_V10", to: "1", .when(traits: ["V10"]))]
// SwiftPM's defaults do not reach Swift's Clang importer.
let swiftSettings: [SwiftSetting] = [.define("SWIFT_PACKAGE")] + v10SwiftSettings
let cSettings: [CSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CSettings
let cxxSettings: [CXXSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CxxSettings

let kscrashDependencyCondition: TargetDependencyCondition? = envSelectsV10
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

if !envSelectsV10 {
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

if !envSelectsV10 {
    // BEGIN:BINARY_TARGETS
    targets += [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/Sentry.xcframework.zip",
            checksum: "86dde13e6145ea3049ee2eb0b07ccb66e137a4d3af0d0dfe0b9d895f80b43237" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/Sentry-Dynamic.xcframework.zip",
            checksum: "53b938aab7f1e3cb0728a7cacdf379ad232c051e39fb4e4ef7b18b31f04b46b6" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "898a489f41aca3141f01c2eabaa536b108971926308822a24f2f185b4a812713" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "9d146d1e8479d47955d5de636071b7e90969659817b92b33e6e7f4da3c1b0304" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "e88f40cc7b8e849a5e1c8b81d08e1967fdbc80050104d63d0b536c24881ba330" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "cc8ebc22f85f1b9ded1c5c346b8e524997d9b49e4d763f1d0e59d55261ccad21" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.31.0/SentryObjC-Static.xcframework.zip",
            checksum: "9bee1b25db8e142230cffdbb9259b4ba848cc04c2e9e82c9ea35b3e05deb48a1" //SentryObjC-Static
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
if envSelectsV10 {
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

var sentryPrivateDependencies: [Target.Dependency] = [
    "SentryHeaders",
    .product(
        name: "Recording",
        package: "KSCrash",
        condition: kscrashDependencyCondition
    )
]
if !envSelectsV10 {
    sentryPrivateDependencies.append(
        .target(name: "_SentryCrashV9Headers")
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

    sentrySwiftTarget,
    .target(
        name: "SentryCrashV9Swift",
        dependencies: ["SentrySwift", "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
        path: "Sources/SentryCrashV9Swift",
        cSettings: v10CSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + v10SwiftSettings
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
if !envSelectsV10 {
    sentryObjCInternalDependencies += [
        .target(name: "SentryCrashV9"),
        .target(name: "_SentryCrashV9Headers")
    ]
}

targets += [
    .target(
        name: "SentryCrashV9",
        dependencies: ["SentryCrashV9Swift", "SentrySwift", "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
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
        ] + v10CSettings
    ),
    // The recorder stays separate from reporter-neutral SDK code. The development V10 trait
    // compiles its guarded sources without recorder implementation; the environment route excludes it.
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
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
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
            "SentrySwift",
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
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: cSettings,
        swiftSettings: [
            .define("SENTRY_NO_UI_FRAMEWORK", .when(traits: ["NoUIFramework"]))
        ] + swiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
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
            "SentrySwift", "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp",
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
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryTestUtils", "SentryTestUtilsObjC"],
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
// Traits cannot remove targets, so source guards also exclude this suite when V10 is selected.
if !envSelectsV10 {
    targets += [
        .testTarget(
            name: "SentryProfilerTests",
            dependencies: ["SentrySwift", "SentryTestUtils", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp"],
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
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "18a633dec20c265f03386294f9d82d208bb13094")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    traits: [
        .init(name: "NoUIFramework", description: "Build without UIKit/AppKit/SwiftUI framework linkage. Use for command-line tools or contexts where UI frameworks are unavailable."),
        .init(name: "V10", description: "Development-only V10 API and KSCrash selection; removed when V9 branches off before V10 release."),
        .init(name: "_SentryInternalUITestSupport", description: "Internal support for Sentry's sample UI tests. Do not enable in production."),
        .init(name: "_SentryTest", description: "Internal SDK unit-test support for local development. Changes SDK behavior; not for consumers or production builds."),
        .init(name: "_SentryTestCI", description: "Internal SDK unit-test support for CI. Changes SDK behavior; not for consumers or production builds.")
    ],
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
