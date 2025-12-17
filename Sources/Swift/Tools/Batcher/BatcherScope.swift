@_implementationOnly import _SentryPrivate

protocol BatcherScope {
    var replayId: String? { get }
    var propagationContextTraceIdString: String { get }
    var span: Span? { get }
    var userObject: User? { get }
    func getContextForKey(_ key: String) -> [String: Any]?
    var attributes: [String: Any] { get }

    func applyToItem<Item: BatcherItem, Config: BatcherConfig<Item>, Metadata: BatcherMetadata>(
        _ item: inout Item,
        config: Config,
        metadata: Metadata
    )
}

extension BatcherScope {
    func applyToItem<Item: BatcherItem, Config: BatcherConfig<Item>, Metadata: BatcherMetadata>(
        _ item: inout Item,
        config: Config,
        metadata: Metadata
    ) {
        addDefaultAttributes(to: &item.attributes, config: config, metadata: metadata)
        addOSAttributes(to: &item.attributes, config: config)
        addDeviceAttributes(to: &item.attributes, config: config)
        addUserAttributes(to: &item.attributes, config: config)
        addReplayAttributes(to: &item.attributes, config: config)
        addScopeAttributes(to: &item.attributes, config: config)
        addDefaultUserIdIfNeeded(to: &item.attributes, config: config, metadata: metadata)

        item.traceId = SentryId(uuidString: propagationContextTraceIdString)
    }

    private func addDefaultAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig, metadata: any BatcherMetadata) {
        attributes["sentry.sdk.name"] = .init(string: SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .init(string: SentryMeta.versionString)
        attributes["sentry.environment"] = .init(string: metadata.environment)
        if let releaseName = metadata.releaseName {
            attributes["sentry.release"] = .init(string: releaseName)
        }
        if let span = self.span {
            attributes["span_id"] = .init(string: span.spanId.sentrySpanIdString)
        }
    }

    private func addOSAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig) {
        guard let osContext = self.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .init(string: osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .init(string: osVersion)
        }
    }

    private func addDeviceAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig) {
        guard let deviceContext = self.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
            return
        }
        // For Apple devices, brand is always "Apple"
        attributes["device.brand"] = .init(string: "Apple")

        if let deviceModel = deviceContext["model"] as? String {
            attributes["device.model"] = .init(string: deviceModel)
        }
        if let deviceFamily = deviceContext["family"] as? String {
            attributes["device.family"] = .init(string: deviceFamily)
        }
    }

    private func addUserAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig) {
        guard config.sendDefaultPii else {
            return
        }
        if let userId = userObject?.userId {
            attributes["user.id"] = .init(string: userId)
        }
        if let userName = userObject?.name {
            attributes["user.name"] = .init(string: userName)
        }
        if let userEmail = userObject?.email {
            attributes["user.email"] = .init(string: userEmail)
        }
    }

    private func addReplayAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig) {
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        if let scopeReplayId = replayId {
            // Session mode: use scope replay ID
            attributes["sentry.replay_id"] = .init(string: scopeReplayId)
        }
#endif
#endif
    }

    private func addScopeAttributes(to attributes: inout [String: SentryAttribute], config: any BatcherConfig) {
        // Scope attributes should not override any existing attribute in the item
        for (key, value) in self.attributes where attributes[key] == nil {
            attributes[key] = .init(value: value)
        }
    }

    private func addDefaultUserIdIfNeeded(
        to attributes: inout [String: SentryAttribute],
        config: any BatcherConfig,
        metadata: any BatcherMetadata
    ) {
        guard attributes["user.id"] == nil && attributes["user.name"] == nil && attributes["user.email"] == nil else {
            return
        }

        if let installationId = metadata.installationId {
            // We only want to set the id if the customer didn't set a user so we at least set something to
            // identify the user.
            attributes["user.id"] = .init(value: installationId)
        }
    }
}

extension Scope: BatcherScope {}
