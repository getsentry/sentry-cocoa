// swiftlint:disable missing_docs
internal import _SentryPrivate

// Feature flag APIs live in this file so the public Scope API has a clear home.
extension Scope {
    @nonobjc public func addFeatureFlag(name: String, result: Bool) {
        addFeatureFlagInternal(name: name, result: result)
    }

    @nonobjc public func clearFeatureFlags() {
        clearFeatureFlagsInternal()
    }
}

extension Scope {
    @discardableResult
    func applyTo(event: Event?, maxBreadcrumbs: UInt) -> Event? {
        applyToEvent(event, maxBreadcrumb: maxBreadcrumbs) as? Event
    }
}

// swiftlint:enable missing_docs
