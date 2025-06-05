// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: [
        .library(name: "Sentry", targets: ["Sentry"]),
        .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
        .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI"]),
        .library(name: "SentryObjc", type: .dynamic, targets: ["SentryObjc"])
    ],
    targets: [
        .binaryTarget(
                    name: "Sentry",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.52.0/Sentry.xcframework.zip",
                    checksum: "1abbe703143bb4b497c2b474e50b76d0c6b5f0d4ddd503e1e2e670e51373c8f8" //Sentry-Static
                ),
        .binaryTarget(
                    name: "Sentry-Dynamic",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.52.0/Sentry-Dynamic.xcframework.zip",
                    checksum: "f873ca5afd1a9aa1b81cb2cc4d0324e7d65b0a5a55903face16efa842f331e36" //Sentry-Dynamic
                ),
        .target ( name: "SentrySwiftUI",
                  dependencies: ["Sentry", "SentryInternal"],
                  path: "Sources/SentrySwiftUI",
                  exclude: ["SentryInternal/", "module.modulemap"],
                  linkerSettings: [
                     .linkedFramework("Sentry")
                  ]
                ),
        .target( name: "SentryInternal",
                 path: "Sources/SentrySwiftUI",
                 sources: [
                    "SentryInternal/"
                 ],
                 publicHeadersPath: "SentryInternal/"
               ),
        .target(name: "SentryHeaders", path: "Sources/Sentry", sources: ["SentryDsn.m"], publicHeadersPath: "Public"),
        .target(name: "_SentryPrivate", dependencies: ["SentryHeaders"], path: "Sources/Sentry", sources: ["NSLocale+Sentry.m"], publicHeadersPath: "include", cSettings: [.headerSearchPath("include/HybridPublic")]),
        .target(
          name: "SentrySwift",
          dependencies: ["_SentryPrivate", "SentryHeaders"],
          path: "Sources/Swift",
          swiftSettings: [
            .unsafeFlags(["-enable-library-evolution", "-Xfrontend", "-application-extension"])
          ],
          linkerSettings: [
            .unsafeFlags(["-Xlinker", "-application_extension"])
          ]),
        .target(name: "SentryObjc", dependencies: ["SentrySwift"], path: "Sources", exclude: ["Sentry/SentryDsn.m", "Sentry/NSLocale+Sentry.m", "Swift", "SentrySwiftUI", "Resources", "Configuration"], cSettings: [.headerSearchPath("Sentry/include/HybridPublic"), .headerSearchPath("Sentry"), .headerSearchPath("SentryCrash/Recording"), .headerSearchPath("SentryCrash/Recording/Monitors"), .headerSearchPath("SentryCrash/Recording/Tools"), .headerSearchPath("SentryCrash/Installations"), .headerSearchPath("SentryCrash/Reporting/Filters"), .headerSearchPath("SentryCrash/Reporting/Filters/Tools")])
    ],
    cxxLanguageStandard: .cxx14
)
