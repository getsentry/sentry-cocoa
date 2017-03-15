import PackageDescription

let package = Package(
    name: "Sentry",
    dependencies : [],
    exclude: [
        "Sources/NotSentry"
    ]
)
