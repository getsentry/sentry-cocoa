@_implementationOnly import _SentryPrivate

protocol BatcherScope {
    var replayId: String? { get }
    var propagationContextTraceIdString: String { get }
    var span: Span? { get }
    var userObject: User? { get }
    func getContextForKey(_ key: String) -> [String: Any]?

    /// List of attributes with erased value type for compatibility with public ``Scope``.
    var attributes: [String: Any] { get }

    /// Used for type-safe access of the attributes, uses default implementation in extension
    var attributesMap: [String: SentryAttributeValue] { get }

    func applyToItem<Item: BatcherItem, Config: BatcherConfig<Item>, Metadata: BatcherMetadata>(
        _ item: inout Item,
        config: Config,
        metadata: Metadata
    )
}

extension BatcherScope {
    var attributesMap: [String: SentryAttributeValue] {
        self.attributes.mapValues { value in
            SentryAttributeValue.from(anyValue: value)
        }
    }

    func applyToItem<Item: BatcherItem, Config: BatcherConfig<Item>, Metadata: BatcherMetadata>(
        _ item: inout Item,
        config: Config,
        metadata: Metadata
    ) {
        addDefaultAttributes(to: &item.attributesMap, config: config, metadata: metadata)
        addOSAttributes(to: &item.attributesMap, config: config)
        addDeviceAttributes(to: &item.attributesMap, config: config)
        addUserAttributes(to: &item.attributesMap, config: config)
        addReplayAttributes(to: &item.attributesMap, config: config)
        addScopeAttributes(to: &item.attributesMap, config: config)
        addDefaultUserIdIfNeeded(to: &item.attributesMap, config: config, metadata: metadata)

        item.traceId = SentryId(uuidString: propagationContextTraceIdString)
    }

    private func addDefaultAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig, metadata: any BatcherMetadata) {
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

    private func addOSAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig) {
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

    private func addDeviceAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig) {
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

    private func addUserAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig) {
        guard config.sendDefaultPii else {
            return
        }
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

    private func addReplayAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig) {
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        if let scopeReplayId = replayId {
            // Session mode: use scope replay ID
            attributes["sentry.replay_id"] = .string(scopeReplayId)
        }
#endif
#endif
    }

    private func addScopeAttributes(to attributes: inout [String: SentryAttributeValue], config: any BatcherConfig) {
        // Scope attributes should not override any existing attribute in the item
        for (key, value) in self.attributesMap where attributes[key] == nil {
            attributes[key] = value
        }
    }

    private func addDefaultUserIdIfNeeded(
        to attributes: inout [String: SentryAttributeValue],
        config: any BatcherConfig,
        metadata: any BatcherMetadata
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

extension Scope: BatcherScope {}
