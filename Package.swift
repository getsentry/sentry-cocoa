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
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.0/Sentry.xcframework.zip",
        checksum: "2e7948d8fac8b7dfbcc24117c2ae02e79757a49ff3dfb15a06866fc405134a38" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.0/Sentry-Dynamic.xcframework.zip",
        checksum: "03f88d2236cb896d45897f3e223aa50d68940734e81d48d96238793bc66bbd42" //Sentry-Dynamic
    ),
    .binaryTarget(
        name: "Sentry-Dynamic-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
        checksum: "56357754f1235d49a0847598a46ed88790b0f7905895010c0e684c38edbad31c" //Sentry-Dynamic-WithARM64e
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
        checksum: "c3ca71808c6feb2a9fcb219a35afa84652c41fcee16b0fa4a6ab62cab23953ea" //Sentry-WithoutUIKitOrAppKit
    ),
    .binaryTarget(
        name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.57.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
        checksum: "00f0805426b3b3defbb9b3dd1a5ceab316cb43e6909764c0f1c54dd206304d02" //Sentry-WithoutUIKitOrAppKit-WithARM64e
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
