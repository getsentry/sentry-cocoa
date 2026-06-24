// swiftlint:disable missing_docs
protocol SentryFeatureFlagValue {
    var asSentryFeatureFlagValue: SentryFeatureFlagValueContent { get }
}

extension Bool: SentryFeatureFlagValue {
    var asSentryFeatureFlagValue: SentryFeatureFlagValueContent {
        return .boolean(self)
    }
}
// swiftlint:enable missing_docs
