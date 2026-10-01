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

let enableV10 = envFlag("SDK_V10")
let v10SwiftSettings: [SwiftSetting] = enableV10 ? [.define("SDK_V10")] : []
let v10CSettings: [CSetting] = enableV10 ? [.define("SDK_V10", to: "1")] : []
let v10CxxSettings: [CXXSetting] = enableV10 ? [.define("SDK_V10", to: "1")] : []

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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/Sentry.xcframework.zip",
            checksum: "46f659ad81a4a53db82f263d5ce5a3d704e6b7f6625518b175a4d1b630cd90a9" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/Sentry-Dynamic.xcframework.zip",
            checksum: "41d93788be7c14b6844b70004f878bf10ba0dc04f902d84a30b288bb05db639f" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "b96888e74104252fbb4db8c4ac1a66f3662678ddebbdde7662a0e92ea558fb46" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "47b6cb3c6634b76296342246317f56969a2f14086b350b8fc1500d9d04fa90a9" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "08e58ee85c6bacd5a3e3135021ebf54c8631bc39c88d5f8f0fee66ee5d453722" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "c246262e23c44b804f14235a55c69d4e5189c5f25f288b40ef655cb6b005bd54" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.0/SentryObjC-Static.xcframework.zip",
            checksum: "84c1f86f80598405bb0ecf29fc7cec0c452c75d7452173962283d09dc5a43d34" //SentryObjC-Static
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
    cSettings: v10CSettings,
    swiftSettings: v10SwiftSettings
)

if enableV10 {
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
] + v10CSettings

let sentryPrivateDependencies: [Target.Dependency] = if enableV10 {
    ["SentryHeaders", .product(name: "Recording", package: "KSCrash")]
} else {
    ["SentryHeaders", "_SentryCrashV9Headers"]
}

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        dependencies: enableV10 ? ["_SentryV10Configuration"] : [],
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
        path: "Sources/SentryCrashV9Swift"
    )
]

var sentryObjCInternalDependencies: [Target.Dependency] = ["SentrySwift"]
if enableV10 {
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
        swiftSettings: v10SwiftSettings + objcCompatSwiftSettings
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ] + v10CSettings
    )
]
// END:OBJC_WRAPPER

targets += [
    .target(
        name: "SentryTestUtilsObjC",
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders", "SentryTestUtilsObjCpp"],
        path: "SentryTestUtils/SourcesObjC",
        publicHeadersPath: "include",
        cSettings: v10CSettings
    ),
    .target(
        name: "SentryTestUtilsObjCpp",
        dependencies: ["SentryObjCInternal", "_SentryPrivate"],
        path: "SentryTestUtils/SourcesObjCpp",
        publicHeadersPath: ".",
        cSettings: v10CSettings,
        cxxSettings: v10CxxSettings,
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
        cSettings: v10CSettings,
        swiftSettings: v10SwiftSettings
    ),
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        cSettings: v10CSettings,
        swiftSettings: v10SwiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        cSettings: v10CSettings,
        swiftSettings: v10SwiftSettings + objcCompatSwiftSettings
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

let packageDependencies: [Package.Dependency] = enableV10 ? [.package(url: "https://github.com/getsentry/KSCrash.git", revision: "18a633dec20c265f03386294f9d82d208bb13094")] : []

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
