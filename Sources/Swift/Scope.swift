// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

// Feature flag APIs live in this file so the eventual public Scope API has a clear home.
// These methods stay SPI while the public surface is being finalized.
extension Scope {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        guard let storage = featureFlagStorage as? SentryFeatureFlagStorage else {
            return
        }
        storage.addFeatureFlag(name: name, result: result)
    }

    @_spi(Private) public func removeFeatureFlag(name: String) {
        guard let storage = featureFlagStorage as? SentryFeatureFlagStorage else {
            return
        }
        storage.removeFeatureFlag(name: name)
    }
}
// swiftlint:enable missing_docs
