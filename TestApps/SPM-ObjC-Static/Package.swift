// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SPM-ObjC-Static",
    platforms: [.macOS(.v12)],
    dependencies: [.package(name: "Sentry", path: "../..")],
    targets: [
        .executableTarget(
            name: "SPM-ObjC-Static",
            dependencies: [.product(name: "Sentry", package: "Sentry")])
    ]
)
