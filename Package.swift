// swift-tools-version:5.3
#if canImport(Darwin)   
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

var products: [Product] = [
    .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
    .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
    .library(name: "swift-log-sentry", targets: ["Sentry", "swift-log-sentry"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.56.1/Sentry.xcframework.zip",
        checksum: "f63ffb0855794a2e03115e5f4890ef69f861871b480d3caa1bef11fe765c7405" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.56.1/Sentry-Dynamic.xcframework.zip",
        checksum: "bcce4f2be93a91c4e3ebbf41b6632be4de308e810f810e016d7b96c62febfb5c" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.56.1/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "eb1a71f0c0bb438b82bd6dee301af3c0d9ecc99eafde790910774faded34d824" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.56.1/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "87f793087bff4507840fcee58936637d0b804c963124b7b4e094950fc5a38351" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.56.1/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "185c204812ae7bed62cff92adb0cbd1641c2ae9183dc000a8c72b7fcc5a0c0c5" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .target (
        name: "SentrySwiftUI",
        dependencies: ["Sentry", "SentryInternal"],
        path: "Sources/SentrySwiftUI",
        exclude: ["SentryInternal/", "module.modulemap"],
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target (
        name: "swift-log-sentry",
        dependencies: ["Sentry", .product(name: "Logging", package: "swift-log")],
        path: "Sources/SwiftLog",
        linkerSettings: [
            .linkedFramework("Sentry")
        ]
    ),
    .target(
        name: "SentryInternal",
        path: "Sources/SentrySwiftUI",
        sources: [
            "SentryInternal/"
        ],
        publicHeadersPath: "SentryInternal/"
    ),
    .target(
        name: "SentryCppHelper",
        dependencies: ["Sentry"],
        path: "Sources/SentryCppHelper",
        linkerSettings: [
         .linkedLibrary("c++")
        ]
    )
]

let env = getenv("EXPERIMENTAL_SPM_BUILDS")
if let env = env, String(cString: env, encoding: .utf8) == "1" {
    products.append(.library(name: "SentrySPM", type: .dynamic, targets: ["SentryObjc"]))
    targets.append(contentsOf: [
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
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("include/HybridPublic")]),
        .target(
            name: "SentrySwift",
            dependencies: ["_SentryPrivate", "SentryHeaders"],
            path: "Sources/Swift",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
                // Some API breaking changes are necessary for the framework to compile with SPM, we’ll ship
                // those in V9.
                .define("SDK_V9")
            ]),
        .target(
            name: "SentryObjc",
            dependencies: ["SentrySwift"],
            path: "Sources",
            exclude: ["Sentry/SentryDummyPublicEmptyClass.m", "Sentry/SentryDummyPrivateEmptyClass.m", "Swift", "SentrySwiftUI", "Resources", "Configuration", "SentryCppHelper"],
            cSettings: [
                .headerSearchPath("Sentry/include/HybridPublic"),
                .headerSearchPath("Sentry"),
                .headerSearchPath("SentryCrash/Recording"),
                .headerSearchPath("SentryCrash/Recording/Monitors"),
                .headerSearchPath("SentryCrash/Recording/Tools"),
                .headerSearchPath("SentryCrash/Installations"),
                .headerSearchPath("SentryCrash/Reporting/Filters"),
                .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
                .define("SDK_V9")]
        )
    ])
}

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0") // TODO: This clases with iOS 11 min target version
    ],
    targets: targets,
    cxxLanguageStandard: .cxx14
)
