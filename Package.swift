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
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.2/Sentry.xcframework.zip",
        checksum: "d5d3aeab545b605a345f27d15d69192ab56f20a5b46775cff6ab6f910701a91e" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.2/Sentry-Dynamic.xcframework.zip",
        checksum: "ea75510a87b285c9a4e3b66a720bdb3940cccb07d67fc08fbdc28dc003f358f5" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.2/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "db93da7d2e39d115c96727b98bb1a915575a16a9bcfa9d468941c822bb3376f3" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.2/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "0fcf652ddced26bfa58c0d29be7f84be20ae139f58310b84b04b1e6eec9ca817" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.2/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "981d72375b712a6bb6bd8ae445473a437f902e8872d04192e111a6d6851dd7d1" //Sentry-WithoutUIKitOrAppKit-WithARM64e
    ),
    .target (
        name: "SentrySwiftUI",
        dependencies: ["Sentry", "SentryInternal"],
        path: "Sources/SentrySwiftUI",
        exclude: ["SentryInternal/", "module.modulemap"],
        linkerSettings: [
            .linkedFramework("Sentry")
        ]),
    .target(
        name: "SentryInternal",
        path: "Sources/SentrySwiftUI",
        sources: [
            "SentryInternal/"
        ],
        publicHeadersPath: "SentryInternal/"),
    .target(
        name: "SentryCppHelper",
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
                .define("SDK_V9")])
    ])
}

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: products,
    targets: targets,
    cxxLanguageStandard: .cxx14
)
