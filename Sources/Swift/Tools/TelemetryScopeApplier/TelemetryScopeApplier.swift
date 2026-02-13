@_implementationOnly import _SentryPrivate

protocol TelemetryScopeApplier {
    var replayId: String? { get }
    var propagationContextTraceId: SentryId { get }
    var span: Span? { get }
    var userObject: User? { get }
    func getContextForKey(_ key: String) -> [String: Any]?

    /// List of attributes with erased value type for compatibility with public ``Scope``.
    var attributes: [String: Any] { get }

    /// Used for type-safe access of the attributes, uses default implementation in extension
    var attributesDict: [String: SentryAttributeContent] { get }

    func addAttributesToItem<Item: TelemetryItem, Metadata: TelemetryScopeMetadata>(
        _ item: inout Item,
        metadata: Metadata
    )
}

extension TelemetryScopeApplier {
    var attributesDict: [String: SentryAttributeContent] {
        self.attributes.mapValues { value in
            SentryAttributeContent.from(anyValue: value)
        }
    }

    func addAttributesToItem<Item: TelemetryItem, Metadata: TelemetryScopeMetadata>(
        _ item: inout Item,
        metadata: Metadata
    ) {
        // Extract attributesDict once to avoid multiple getter/setter calls on computed property
        // Each inout parameter access triggers both getter and setter, which is expensive for
        // computed properties that perform dictionary conversions.
        var attributes = item.attributesDict

        addDefaultAttributes(to: &attributes, metadata: metadata)
        addOSAttributes(to: &attributes)
        addDeviceAttributes(to: &attributes)
        addUserAttributes(to: &attributes, metadata: metadata)
        addReplayAttributes(to: &attributes)
        addScopeAttributes(to: &attributes)
        addDefaultUserIdIfNeeded(to: &attributes, metadata: metadata)

        // Set the modified dictionary back once
        item.attributesDict = attributes
        // When a span is active, use its traceId to ensure consistency with span_id.
        // Otherwise, fall back to propagationContext traceId.
        item.traceId = span?.traceId ?? propagationContextTraceId
    }

    private func addDefaultAttributes(to attributes: inout [String: SentryAttributeContent], metadata: any TelemetryScopeMetadata) {
        attributes["sentry.sdk.name"] = .string(SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .string(SentryMeta.versionString)
        attributes["sentry.environment"] = .string(metadata.environment)
        if let releaseName = metadata.releaseName {
            attributes["sentry.release"] = .string(releaseName)
        }
        if let span = self.span {
            attributes["span_id"] = .string(span.spanId.sentrySpanIdString)
        }
    }

    private func addOSAttributes(to attributes: inout [String: SentryAttributeContent]) {
        guard let osContext = self.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .string(osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .string(osVersion)
        }
    }

    private func addDeviceAttributes(to attributes: inout [String: SentryAttributeContent]) {
        guard let deviceContext = self.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
            return
        }
        // For Apple devices, brand is always "Apple"
        attributes["device.brand"] = .string("Apple")

        if let deviceModel = deviceContext["model"] as? String {
            attributes["device.model"] = .string(deviceModel)
        }
        if let deviceFamily = deviceContext["family"] as? String {
            attributes["device.family"] = .string(deviceFamily)
        }
    }

    private func addUserAttributes(to attributes: inout [String: SentryAttributeContent], metadata _: any TelemetryScopeMetadata) {
        if let userId = userObject?.userId {
            attributes["user.id"] = .string(userId)
        }
        if let userName = userObject?.name {
            attributes["user.name"] = .string(userName)
        }
        if let userEmail = userObject?.email {
            attributes["user.email"] = .string(userEmail)
        }
    }

    private func addReplayAttributes(to attributes: inout [String: SentryAttributeContent]) {
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
        if let scopeReplayId = replayId {
            // Session mode: use scope replay ID
            attributes["sentry.replay_id"] = .string(scopeReplayId)
        }
#endif
#endif
    }

    private func addScopeAttributes(to attributes: inout [String: SentryAttributeContent]) {
        // Scope attributes should not override any existing attribute in the item
        for (key, value) in self.attributesDict where attributes[key] == nil {
            attributes[key] = value
        }
    }

    private func addDefaultUserIdIfNeeded(
        to attributes: inout [String: SentryAttributeContent],
        metadata: any TelemetryScopeMetadata
    ) {
        guard attributes["user.id"] == nil && attributes["user.name"] == nil && attributes["user.email"] == nil else {
            return
        }

        if let installationId = metadata.installationId {
            // We only want to set the id if the customer didn't set a user so we at least set something to
            // identify the user.
            attributes["user.id"] = .string(installationId)
        }
    }
}

extension Scope: TelemetryScopeApplier {}
