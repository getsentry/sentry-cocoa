// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v9), .macOS(.v10_10), .tvOS(.v9), .watchOS(.v2)],
    products: [
        .library(
            name: "Sentry",
            targets: ["Sentry"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Sentry",
            path: "Sources",
            exclude: [
                "Samples", 
                "scripts",
                "Tests",
                "Utils"
            ],
            sources: [
                "Sentry/",
                "SentryCrash/"
            ],
            publicHeadersPath: "Sentry/Public/",
            cxxSettings: [
                .define("GCC_ENABLE_CPP_EXCEPTIONS", to: "YES"),
                .headerSearchPath("Sentry/include"),
                .headerSearchPath("Sentry/Public"),
                .headerSearchPath("SentryCrash/Installations"),
                .headerSearchPath("SentryCrash/Recording"),
                .headerSearchPath("SentryCrash/Recording/Monitors"),
                .headerSearchPath("SentryCrash/Recording/Tools"),
                .headerSearchPath("SentryCrash/Reporting/Filters"),
                .headerSearchPath("SentryCrash/Reporting/Filters/Tools"),
                .headerSearchPath("SentryCrash/Reporting/Tools")
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++")
            ]
        ),

        .testTarget(
            name: "SentrySwiftTests",
            dependencies: [
                "Sentry"
            ],
            path: "Tests/SentryTests",
            sources: [
                "SentrySwiftTests.swift"
            ]
        )
    ]
)
