import Foundation

/**
 * A wrapper around a dispatch timer source that can be subclassed for mocking in tests.
 */
@objc
public class SentryDispatchSourceWrapper: NSObject {
    private let queueWrapper: SentryDispatchQueueWrapper
    private let source: DispatchSourceTimer
    
    @objc
    public init(interval: UInt64, leeway: UInt64, queue queueWrapper: SentryDispatchQueueWrapper, eventHandler: @escaping () -> Void) {
        self.queueWrapper = queueWrapper
        
        // Create dispatch timer source using modern Swift APIs
        self.source = DispatchSource.makeTimerSource(queue: queueWrapper.queue)
        
        super.init()
        
        // Configure the timer
        source.setEventHandler(handler: eventHandler)
        source.schedule(
            deadline: .now(),
            repeating: .nanoseconds(Int(interval)),
            leeway: .nanoseconds(Int(leeway))
        )
        source.resume()
    }
    
    @objc
    public func cancel() {
        source.cancel()
    }
    
    #if SENTRY_TEST || SENTRY_TEST_CI
    @objc
    public var dispatchSource: DispatchSourceTimer {
        return source
    }
    
    @objc
    public var queue: SentryDispatchQueueWrapper {
        return queueWrapper
    }
    #endif // SENTRY_TEST || SENTRY_TEST_CI
}
