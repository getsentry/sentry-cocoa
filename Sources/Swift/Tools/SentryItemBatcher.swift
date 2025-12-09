@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryItemBatcherDelegate: AnyObject {
    func capture(itemBatcherData: Data, count: Int)
}

protocol SentryItemBatcherItem: Encodable {
    var attributes: [String: SentryAttribute] { get set }
    var traceId: SentryId { get set }
    var body: String { get }
}

final class SentryItemBatcher<Item: SentryItemBatcherItem> {
    struct Config {
        let beforeSendItem: ((Item) -> Item?)?
        let environment: String
        let releaseName: String?

        let flushTimeout: TimeInterval
        let maxItemCount: Int
        let maxBufferSizeBytes: Int

        let getInstallationId: () -> String?
    }

    private let config: Config
    private let dispatchQueue: SentryDispatchQueueWrapperProtocol

    // Every items data is added sepratley. They are flushed together in an envelope.
    private var encodedItems: [Data] = []
    private var encodedItemsSize: Int = 0
    private var timerWorkItem: DispatchWorkItem?

    ///  The delegate to handle captured item batches
    weak var delegate: SentryItemBatcherDelegate?

    /// Initializes a new SentryItemBatcher.
    /// - Parameters:
    ///   - options: The Sentry configuration options
    ///   - flushTimeout: The timeout interval after which buffered items will be flushed
    ///   - maxItemCount: Maximum number of items to batch before triggering an immediate flush.
    ///   - maxBufferSizeBytes: The maximum buffer size in bytes before triggering an immediate flush
    ///   - dispatchQueue: A **serial** dispatch queue wrapper for thread-safe access to mutable state
    ///
    /// - Important: The `dispatchQueue` parameter MUST be a serial queue to ensure thread safety.
    ///              Passing a concurrent queue will result in undefined behavior and potential data races.
    ///
    /// - Note: Items are flushed when either `maxItemCount` or `maxBufferSizeBytes` limit is reached.
    @_spi(Private) public init(
        config: Config,
        dispatchQueue: SentryDispatchQueueWrapperProtocol
    ) {
        self.config = config
        self.dispatchQueue = dispatchQueue
    }
    
    func addItem(_ item: Item, scope: Scope) {
        var item = item
        addDefaultAttributes(to: &item.attributes, scope: scope)
        addOSAttributes(to: &item.attributes, scope: scope)
        addDeviceAttributes(to: &item.attributes, scope: scope)
        addUserAttributes(to: &item.attributes, scope: scope)
        addReplayAttributes(to: &item.attributes, scope: scope)
        addScopeAttributes(to: &item.attributes, scope: scope)
        addDefaultUserIdIfNeeded(to: &item.attributes, scope: scope)

        let propagationContextTraceIdString = scope.propagationContextTraceIdString
        item.traceId = SentryId(uuidString: propagationContextTraceIdString)

        // The before send item closure can be used to drop items by returning nil
        // In case it is nil, we can stop processing
        if let beforeSendItem = config.beforeSendItem {
            guard let processedItem = beforeSendItem(item) else {
                return
            }
            item = processedItem
        }

        dispatchQueue.dispatchAsync { [weak self] in
            self?.encodeAndBuffer(item: item)
        }
    }

    // Captures batched items sync and returns the duration.
    @discardableResult
    @_spi(Private) @objc public func captureItems() -> TimeInterval {
        let startTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        dispatchQueue.dispatchSync { [weak self] in
            self?.performCaptureItems()
        }
        let endTimeNs = SentryDefaultCurrentDateProvider.getAbsoluteTime()
        return TimeInterval(endTimeNs - startTimeNs) / 1_000_000_000.0 // Convert nanoseconds to seconds
    }

    // Helper

    private func addDefaultAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
        attributes["sentry.sdk.name"] = .init(string: SentryMeta.sdkName)
        attributes["sentry.sdk.version"] = .init(string: SentryMeta.versionString)
        attributes["sentry.environment"] = .init(string: config.environment)
        if let releaseName = config.releaseName {
            attributes["sentry.release"] = .init(string: releaseName)
        }
        if let span = scope.span {
            attributes["sentry.trace.parent_span_id"] = .init(string: span.spanId.sentrySpanIdString)
        }
    }

    private func addOSAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
        guard let osContext = scope.getContextForKey(SENTRY_CONTEXT_OS_KEY) else {
            return
        }
        if let osName = osContext["name"] as? String {
            attributes["os.name"] = .init(string: osName)
        }
        if let osVersion = osContext["version"] as? String {
            attributes["os.version"] = .init(string: osVersion)
        }
    }
    
    private func addDeviceAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
        guard let deviceContext = scope.getContextForKey(SENTRY_CONTEXT_DEVICE_KEY) else {
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

    private func addUserAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
        guard let user = scope.userObject else {
            return
        }
        if let userId = user.userId {
            attributes["user.id"] = .init(string: userId)
        }
        if let userName = user.name {
            attributes["user.name"] = .init(string: userName)
        }
        if let userEmail = user.email {
            attributes["user.email"] = .init(string: userEmail)
        }
    }

    private func addReplayAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
        if let scopeReplayId = scope.replayId {
            // Session mode: use scope replay ID
            attributes["sentry.replay_id"] = .init(string: scopeReplayId)
        }
#endif
#endif
    }
    
    private func addScopeAttributes(to attributes: inout [String: SentryAttribute], scope: Scope) {
        // Scope attributes should not override any existing attribute in the item
        for (key, value) in scope.attributes where attributes[key] == nil {
            attributes[key] = .init(value: value)
        }
    }
    
    private func addDefaultUserIdIfNeeded(to attributes: inout [String: SentryAttribute], scope: Scope) {
        guard attributes["user.id"] == nil && attributes["user.name"] == nil && attributes["user.email"] == nil else {
            return
        }
        
        if let installationId = config.getInstallationId() {
            // We only want to set the id if the customer didn't set a user so we at least set something to
            // identify the user.
            attributes["user.id"] = .init(value: installationId)
        }
    }

    // Only ever call this from the serial dispatch queue.
    private func encodeAndBuffer(item: Item) {
        do {
            let encodedItem = try encodeToJSONData(data: item)
            
            let encodedItemsWereEmpty = encodedItems.isEmpty
            
            encodedItems.append(encodedItem)
            encodedItemsSize += encodedItem.count
            
            // Flush when we reach max item count or max buffer size
            if encodedItems.count >= config.maxItemCount || encodedItemsSize >= config.maxBufferSizeBytes {
                performCaptureItems()
            } else if encodedItemsWereEmpty && timerWorkItem == nil {
                startTimer()
            }
        } catch {
            SentrySDKLog.error("Failed to encode item: \(error)")
        }
    }
    
    // Only ever call this from the serial dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            SentrySDKLog.debug("Timer fired, calling performFlush().")
            self?.performCaptureItems()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.dispatch(after: config.flushTimeout, workItem: timerWorkItem)
    }

    // Only ever call this from the serial dispatch queue.
    private func performCaptureItems() {
        // Reset items on function exit
        defer {
            encodedItems.removeAll()
            encodedItemsSize = 0
        }
        
        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil
        
        guard encodedItems.count > 0 else {
            SentrySDKLog.debug("No items to flush.")
            return
        }

        // Create the payload.
        let payloadData = Data("{\"items\":[".utf8) + encodedItems.joined(separator: Data(",".utf8)) + Data("]}".utf8)
        
        // Send the payload.
        
        guard let delegate else {
            SentrySDKLog.debug("Delegate not set, not capturing items data.")
            return
        }
        delegate.capture(itemBatcherData: payloadData, count: encodedItems.count)
    }
}
