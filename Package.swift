// swift-tools-version:6.0

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

var products: [Product] = [
    // BEGIN:BINARY_PRODUCTS
    .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
    .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"]),
    .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"]),
    // END:BINARY_PRODUCTS
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

var targets: [Target] = [
    // BEGIN:BINARY_TARGETS
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/Sentry.xcframework.zip",
        checksum: "7e3966c543697a8d51f337dc357cfcf99e80942c6931c6457e0a49c113133cd4" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/Sentry-Dynamic.xcframework.zip",
        checksum: "d5a23c79ab69703a3818f885989a60349a67aa2e096a914c352bb26f51b97936" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "e738049bf501b6bf7cca196756a10f9b80e1ff7f52a6a59943f539941775fc40" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "11a2a68ddd3a82251dfe86ed4fd95936e045a34b6a7b0d9b6f0d948f985e2051" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "73ddc5baa32d9dac4cc927f6aee2922e975a2df1296901dae5f97fabda0685ac" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .binaryTarget(
        name: "SentryObjC-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/SentryObjC-Dynamic.xcframework.zip",
        checksum: "aadf42e91038502108c0a6cf23460fa6b916e00fd3e4aa942149f22a4f914c6c" //SentryObjC-Dynamic
    ),
    .binaryTarget(
        name: "SentryObjC-Static",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.16.1/SentryObjC-Static.xcframework.zip",
        checksum: "cc109b013f1b956a983f76982034a357083d1d72d5e6c41a9c96f6e9bffce2fa" //SentryObjC-Static
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
    ),
    // END:BINARY_TARGETS
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

// Targets required to support compile-from-source builds via SPM.
products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        path: "Sources/Sentry",
        sources: ["SentryDummyPublicEmptyClass.m"],
        publicHeadersPath: "Public"
    ),
    .target(
        name: "_SentryPrivate",
        dependencies: ["SentryHeaders"],
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include"),
    .target(
        name: "SentrySwift",
        dependencies: [
            "_SentryPrivate",
            "SentryHeaders",
            .product(name: "Recording", package: "kscrash"),
            .product(name: "Reporting", package: "kscrash"),
            .product(name: "Installations", package: "kscrash"),
            .product(name: "Filters", package: "kscrash"),
            .product(name: "Sinks", package: "kscrash"),
            .product(name: "BootTimeMonitor", package: "kscrash"),
            .product(name: "DemangleFilter", package: "kscrash"),
            .product(name: "DiscSpaceMonitor", package: "kscrash")
        ],
        path: "Sources/Swift",
        swiftSettings: [
            .unsafeFlags(["-enable-library-evolution"])
        ]),

    // SentryObjCInternal compiles all ObjC/C sources from the repo. Named "Internal"
    // to reserve "SentryObjC" for a future public Objective-C wrapper around the SDK.
    .target(
        name: "SentryObjCInternal",
        dependencies: [
            "SentrySwift",
            .product(name: "Recording", package: "kscrash"),
            .product(name: "Reporting", package: "kscrash"),
            .product(name: "Installations", package: "kscrash"),
            .product(name: "Filters", package: "kscrash"),
            .product(name: "Sinks", package: "kscrash"),
            .product(name: "BootTimeMonitor", package: "kscrash"),
            .product(name: "DemangleFilter", package: "kscrash"),
            .product(name: "DiscSpaceMonitor", package: "kscrash")
        ],
        path: "Sources",
        exclude: [
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
        ],
        cSettings: [
            .headerSearchPath("Sentry")])
]

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat"),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ]
    )
]
// END:OBJC_WRAPPER

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: products,
    dependencies: [
        .package(
            url: "https://github.com/kstenerud/KSCrash",
            from: "2.5.1"
        )
    ],
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
