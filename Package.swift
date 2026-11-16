// swift-tools-version:6.0

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
let v10SwiftSettings: [SwiftSetting] = envSelectsV10 ? [.define("SDK_V10")] : []
let v10CSettings: [CSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let v10CxxSettings: [CXXSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
// SwiftPM's defaults do not reach Swift's Clang importer.
let swiftSettings: [SwiftSetting] = [.define("SWIFT_PACKAGE")] + v10SwiftSettings
let cSettings: [CSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CSettings
let cxxSettings: [CXXSetting] = [.define("SWIFT_PACKAGE", to: "1")] + v10CxxSettings

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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/Sentry.xcframework.zip",
            checksum: "730e08dc6b505f02583f6fe46844e8019af550d14d5df46bb55d13fcc835473b" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/Sentry-Dynamic.xcframework.zip",
            checksum: "4c93e1bd2e02482db35a48385d9b87400c826af1b1eac77a40eb5b9bc048dfc7" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "aeefda96700e0c0c292e3b1d427f91b79f1a2bbd43652ca98d68bd03218bcb47" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "2f3e2db38ce1427be64172d81c14713fb93cc1f77e82b6fc8940f3d39641abe8" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "074316565d82535171c7156b3160acc691eafc9d63f2216dbb11f05600091b12" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/SentryObjC-Dynamic.xcframework.zip",
            checksum: "5ff3859cbc5a0b4aa2928181870bc21a58b6503217fd418f4c4186364917a86e" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.3/SentryObjC-Static.xcframework.zip",
            checksum: "14e0f5ce5e1a9ef212ad5ac11fb08c8688732480ee4b00d7df3b41b9fd36203d" //SentryObjC-Static
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

    sentrySwiftTarget,
    .target(
        name: "SentryCrashV9Swift",
        dependencies: ["SentrySwift", "_SentryPrivate", "_SentryCrashV9Headers", "SentryHeaders"],
        path: "Sources/SentryCrashV9Swift"
    )
]

var sentryObjCInternalDependencies: [Target.Dependency] = ["SentrySwift"]
if envSelectsV10 {
    sentryObjCInternalDependencies.append(.product(name: "Recording", package: "KSCrash"))
} else {
    sentrySwiftTarget.dependencies.append("_SentryCrashV9Headers")
    sentryObjCInternalDependencies += ["SentryCrashV9", "_SentryCrashV9Headers"]
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
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
        path: "SentryTestUtils/SourcesObjC",
        cSettings: [.headerSearchPath(".")] + cSettings,
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
            "SentrySwift",
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
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: cSettings,
        swiftSettings: swiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        cSettings: cSettings,
        swiftSettings: swiftSettings + objcCompatSwiftSettings
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

let packageDependencies: [Package.Dependency] = envSelectsV10 ? [.package(url: "https://github.com/getsentry/KSCrash.git", revision: "18a633dec20c265f03386294f9d82d208bb13094")] : []

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
