// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

// Feature flag APIs live in this file so the public Scope API has a clear home.
extension Scope {
    @nonobjc public func addFeatureFlag(name: String, result: Bool) {
        addFeatureFlagInternal(name: name, result: result)
    }
}

// swiftlint:enable missing_docs
