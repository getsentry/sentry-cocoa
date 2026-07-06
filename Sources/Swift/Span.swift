// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

extension Span {
    func addFeatureFlag(name: String, result: Bool) {
        guard let span = self as? SentrySpanInternal else {
            return
        }
        span.addFeatureFlagInternal(name: name, result: result)
    }
}
// swiftlint:enable missing_docs
