// swiftlint:disable missing_docs
internal import _SentryPrivate

// Feature flag APIs live in this file so the public Scope API has a clear home.
extension Scope {
    @nonobjc public func addFeatureFlag(name: String, result: Bool) {
        SentryDependencyContainer.sharedInstance().startOptions?.addSdkFeature("featureFlags")
        addFeatureFlagInternal(name: name, result: result)
    }

    @nonobjc public func clearFeatureFlags() {
        clearFeatureFlagsInternal()
    }
}

// swiftlint:enable missing_docs
