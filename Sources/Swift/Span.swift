// swiftlint:disable missing_docs
internal import _SentryPrivate

// Feature flag APIs live in this file so the eventual public Span API has a clear home.
// These methods stay SPI while the public surface is being finalized.
extension Span {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let span = self as? SentrySpanInternal else {
            return
        }
        SentryDependencyContainer.sharedInstance().startOptions?.markFeatureFlagsUsed()
        span.addFeatureFlagInternal(name: name, result: result)
    }
}
// swiftlint:enable missing_docs
