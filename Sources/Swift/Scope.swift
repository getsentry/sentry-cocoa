// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

// Feature flag APIs live in this file so the eventual public Scope API has a clear home.
// These methods stay SPI while the public surface is being finalized.
extension Scope {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let wrapper = featureFlagBuffer as? SentryFeatureFlagBufferWrapper else {
            return
        }
        wrapper.buffer.add(name: name, value: result)
    }

    @_spi(Private) public func removeFeatureFlag(name: String) {
        guard let wrapper = featureFlagBuffer as? SentryFeatureFlagBufferWrapper else {
            return
        }
        wrapper.buffer.remove(name: name)
    }
}
// swiftlint:enable missing_docs
