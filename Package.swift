import PackageDescription

let package = Package(
    name: "Sentry",
    exclude: [
        "Tests",
        "Sources/Configuration",
        "Sources/KSCrash"
    ]
)
