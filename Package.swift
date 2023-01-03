// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: [
        .library(name: "Sentry", targets: ["Sentry"]),
        .library(name: "Sentry-Dynamic", type: .dynamic, targets: ["Sentry"]),
        .library(name: "SentrySwiftUI", targets: ["SentrySwiftUI"])
    ],
    targets: [
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
                .headerSearchPath("Sentry/include/HybridPublic"),
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
               ),
        .target ( name: "SentrySwiftUI",
                  dependencies: ["Sentry", "SentryInternal"],
                  path: "Sources",
                  exclude: ["SentrySwiftUI/SentryInternal/"],
                  sources: [
                    "SentrySwiftUI"
                  ]
                ),
        //SentryInternal is how we expose some internal Sentry SDK classes to SentrySwiftUI.
        .target( name: "SentryInternal",
                 path: "Sources",
                 sources: [
                    "SentrySwiftUI/SentryInternal/"
                 ],
                 publicHeadersPath: "SentrySwiftUI/SentryInternal/"
               )
    ],
    cxxLanguageStandard: .cxx14
)
