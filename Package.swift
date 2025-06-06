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
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.52.1/Sentry.xcframework.zip",
                    checksum: "48a6c6693148a3f9096108164eb938a931b964395fcf38e169383b9e4cffcfc5" //Sentry-Static
                ),
        .binaryTarget(
                    name: "Sentry-Dynamic",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.52.1/Sentry-Dynamic.xcframework.zip",
                    checksum: "b9d9054c65ee5ac0591c27826edddc54490a96c2a83dee25519cae0c1a593231" //Sentry-Dynamic
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
