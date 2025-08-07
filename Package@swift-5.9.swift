// swift-tools-version:5.9
#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

var products: [Product] = [
    .library(name: "Sentry", targets: ["Sentry"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.54.0/Sentry.xcframework.zip",
        checksum: "f0f4b5582f7fef029ddedd22b6b9894a6d2d31ea9c7b52a2133b1ec7c4cff206" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.54.0/Sentry-Dynamic.xcframework.zip",
        checksum: "2cd3ee298133ed3a6d3b98f3b040e5c67b752887e67647ae671f450ecfd3facf" //Sentry-Dynamic
    ),
    .target (
        name: "SentrySwiftUI",
        dependencies: ["Sentry", "SentryInternal"],
        path: "Sources/SentrySwiftUI",
        exclude: ["SentryInternal/", "module.modulemap"],
        swiftSettings: [
            .interoperabilityMode(.Cxx, .when(platforms: [.visionOS]))
        ],
        linkerSettings: [
            .linkedFramework("Sentry")
        ]),
    .target(
        name: "SentryInternal",
        path: "Sources/SentrySwiftUI",
        sources: [
            "SentryInternal/"
        ],
        publicHeadersPath: "SentryInternal/")
]

let env = getenv("EXPERIMENTAL_SPM_BUILDS")
if let env = env, String(cString: env) == "1" {
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
            exclude: ["Sentry/SentryDummyPublicEmptyClass.m", "Sentry/SentryDummyPrivateEmptyClass.m", "Swift", "SentrySwiftUI", "Resources", "Configuration"],
            publicHeadersPath: "",
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
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4), .visionOS(.v1)],
    products: products,
    targets: targets,
    cxxLanguageStandard: .cxx14
)
