import PackageDescription

let package = Package(
    name: "Sentry",
    targets: [
        Target(
            name: "SentrySwift",
            dependencies: ["Sentry"]
        ),
        Target(name: "Sentry")
    ],
    exclude: [
        "Tests",
        "Configuration"
    ]
)
