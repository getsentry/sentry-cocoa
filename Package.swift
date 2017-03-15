import PackageDescription

let package = Package(
    name: "Sentry",
    dependencies : [],
    exclude: [
        "Sources/Sentry/KSCrash",
        "Sources/Sentry/ios"
    ]
)
