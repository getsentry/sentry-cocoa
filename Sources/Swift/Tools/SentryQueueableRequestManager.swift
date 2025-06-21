@_implementationOnly import _SentryPrivate

@objc @_spi(Private) public final class SentryQueueableRequestManager: NSObject, RequestManager {
    private let session: URLSession
    private let queue: OperationQueue
    
    @objc
    public init(session: URLSession) {
        self.session = session
        self.queue = OperationQueue()
        self.queue.name = "io.sentry.QueueableRequestManager.OperationQueue"
        self.queue.maxConcurrentOperationCount = 3
    }
    
    public var isReady: Bool {
    #if SENTRY_TEST || SENTRY_TEST_CI
        // force every envelope to be cached in UI tests so we can inspect what the SDK would've sent
        // for a given operation
        if ProcessInfo.processInfo.environment["--io.sentry.sdk-environment"] == "ui-tests" {
            return false
        }
    #elseif DEBUG
        if ProcessInfo.processInfo.arguments.contains("--io.sentry.disable-http-transport") {
            return false
        }
    #endif // SENTRY_TEST || SENTRY_TEST_CI

        // We always have at least one operation in the queue when calling this
        return self.queue.operationCount <= 1
    }
    
    public func add(_ request: URLRequest, completionHandler: SentryRequestOperationFinished?) {
        let operation = SentryRequestOperation(session: self.session, request: request) { response, error in
            SentryLog.debug("Queued requests: \(self.queue.operationCount - 1)")
            completionHandler?(response, error)
        }
        self.queue.addOperation(operation)
    }
}
