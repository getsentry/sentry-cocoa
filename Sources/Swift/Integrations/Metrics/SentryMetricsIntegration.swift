final class SentryMetricsIntegration<Dependencies>: NSObject, SwiftIntegration {
    init?(with options: Options, dependencies: Dependencies) {
        guard options.experimental.enableMetrics else { return nil }

        SentrySDKLog.debug("Integration initialized")
    }

    func uninstall() {}

    static var name: String {
        "SentryMetricsIntegration"
    }
}
