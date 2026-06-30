// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

// Feature flag APIs live in this file so the public Span API has a clear home.
extension Span {
    public func addFeatureFlag(name: String, result: Bool) {
        guard let span = self as? SentrySpanInternal else {
            return
        }
        span.addFeatureFlagInternal(name: name, result: result)
    }
}
// swiftlint:enable missing_docs
