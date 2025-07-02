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
    .library(name: "Sentry", targets: ["Sentry"]),
    .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
    .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI"])
]

var targets: [Target] = [
    .binaryTarget(
        name: "Sentry",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.53.1/Sentry.xcframework.zip",
        checksum: "f2c1d1dfaa102edac4c5270bbf0b57977d9ef61985b17a1f277cb72ac6c80302" //Sentry-Static
    ),
    .binaryTarget(
        name: "Sentry-Dynamic",
        url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.53.1/Sentry-Dynamic.xcframework.zip",
        checksum: "8b643291cd90d59672dfcf57be4eef53b6e17c6270d1ffb35903eef523b16bad" //Sentry-Dynamic
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
        publicHeadersPath: "SentryInternal/")
]

let env = getenv("EXPERIMENTAL_SPM_BUILDS")
if let env = env, String(cString: env, encoding: .utf8) == "1" {
    products.append(.library(name: "SentrySPM", type: .dynamic, targets: ["SentryObjc"]))
    targets.append(contentsOf: [
        // At least one source file is required
        .target(name: "SentryHeaders", path: "Sources/Sentry", sources: ["SentryDsn.m"], publicHeadersPath: "Public"),
        .target(
            name: "_SentryPrivate",
            dependencies: ["SentryHeaders"],
            path: "Sources/Sentry",
            sources: ["NSLocale+Sentry.m"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("include/HybridPublic")]),
        .target(
            name: "SentrySwift",
            dependencies: ["_SentryPrivate", "SentryHeaders"],
            path: "Sources/Swift",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
                // This flag is used to make some API breaking changes necessary for the framework to compile with SPM.
                // We can either make more extensive changes to allow it to be backwards compatible, or release them as part of a V9 release.
                // For now we use this flag so that CI can compile the SPM version.
                    .define("SENTRY_SWIFT_PACKAGE")
            ]),
        .target(
            name: "SentryObjc",
            dependencies: ["SentrySwift"],
            path: "Sources",
            exclude: ["Sentry/SentryDsn.m", "Sentry/NSLocale+Sentry.m", "Swift", "SentrySwiftUI", "Resources", "Configuration"],
            cSettings: [
                .headerSearchPath("Sentry/include/HybridPublic"),
                .headerSearchPath("Sentry"),
                .headerSearchPath("SentryCrash/Recording"),
                .headerSearchPath("SentryCrash/Recording/Monitors"),
                .headerSearchPath("SentryCrash/Recording/Tools"),
                .headerSearchPath("SentryCrash/Installations"),
                .headerSearchPath("SentryCrash/Reporting/Filters"),
                .headerSearchPath("SentryCrash/Reporting/Filters/Tools")])
    ])
}

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: products,
    targets: targets,
    cxxLanguageStandard: .cxx14
)
