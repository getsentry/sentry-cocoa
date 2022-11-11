// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v9), .macOS(.v10_10), .tvOS(.v9), .watchOS(.v2)],
    products: [
        .library(name: "Sentry", targets: ["Sentry"]),
        .library(name: "Sentry-Dynamic", type: .dynamic, targets: ["Sentry"]),
        .library(name: "SentrySwiftUI", targets: ["SentrySwiftUI"])
    ],
    targets: [
        .target ( name: "SentrySwiftUI",
                  dependencies: ["Sentry", "SentryInternal"],
                  path: "Sources",
                  sources: [
                    "SentrySwiftUI"
                  ]
        ),
        .target( name: "SentryInternal",
                 path: "Sources",
                 sources: [
                  "PrivateSentry/"
                 ],
                 publicHeadersPath: "PrivateSentry/"
        ),
        .target(
            name: "Sentry",
            dependencies: ["SentryPrivate"],
            path: "Sources",
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
        .target( name: "SentryPrivate",
                 path: "Sources",
                 sources: [
                    "Swift"
                 ]
               )
    ],
    cxxLanguageStandard: .cxx14
)
