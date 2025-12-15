final class MetricsIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetrics else { return nil }

        SentrySDKLog.debug("Integration initialized")
    }

    func uninstall() {}

    static var name: String {
        "MetricsIntegration"
    }
}
