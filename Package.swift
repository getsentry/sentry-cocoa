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
// Environment V10 removes the binary Sentry target, freeing its module name for source builds.
// V9 keeps SentrySwift until the V9 branch split. SDK_V10=1 selects both the
// V10 implementation and the Sentry module; traits never select a different SDK.
let sentrySwiftTargetName = envSelectsV10 ? "Sentry" : "SentrySwift"
let v10SwiftSettings: [SwiftSetting] = envSelectsV10 ? [.define("SDK_V10")] : []
let v10CSettings: [CSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let v10CxxSettings: [CXXSetting] = envSelectsV10 ? [.define("SDK_V10", to: "1")] : []
let swiftSettings: [SwiftSetting] = [.define("SWIFT_PACKAGE")] + v10SwiftSettings
// SwiftPM's defaults do not reach Swift's Clang importer.
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
if envSelectsV10 {
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

sentrySwiftTarget.dependencies += [
    .product(name: "Recording", package: "KSCrash"),
    .product(name: "RecordingCore", package: "KSCrash")
]

let sentryObjCInternalExcludes = [
    "Sentry/SentryDummyPublicEmptyClass.m",
    "Sentry/SentryDummyPrivateEmptyClass.m",
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

let sentryPrivateDependencies: [Target.Dependency] = [
    "SentryHeaders", .product(name: "Recording", package: "KSCrash")
]

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
        name: "_SentryPrivate",
        dependencies: sentryPrivateDependencies,
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include",
        cSettings: cSettings
    ),

    sentrySwiftTarget
]

let sentryObjCInternalDependencies: [Target.Dependency] = [
    .target(name: sentrySwiftTargetName), .product(name: "Recording", package: "KSCrash")
]

targets += [
    // The SDK's ObjC/C sources use KSCrash in every source-build configuration.
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
        ],
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
    .package(path: "SentryTestUtilsDynamic"),
    .package(url: "https://github.com/getsentry/KSCrash.git", revision: "e41302af9fbcf4d9cc6cc95933cb989a90941d37")
]

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
