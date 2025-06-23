import Foundation

/**
 * A wrapper around DispatchQueue functions for testability.
 */
@_spi(Private) @objc public class SentryDispatchQueueWrapper: NSObject {
    
    @objc public let queue: DispatchQueue
    
    @objc public var usesDispatchOnce: Bool {
        true
    }

    @objc public override init() {
        // DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL is requires iOS 10. Since we are targeting
        // iOS 9 we need to manually add the autoreleasepool.
        self.queue = DispatchQueue(label: "io.sentry.default", qos: .default)
        super.init()
    }
    
    @objc public init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
    }
    
    @objc public init(utilityNamed name: String) {
        self.queue = DispatchQueue(label: name, qos: .utility)
        super.init()
    }
    
    @objc public init(conccurentUtilityNamed name: String) {
        self.queue = DispatchQueue(label: name, qos: .utility, attributes: .concurrent)
        super.init()
    }
    
    @objc public init(utilityNamed name: String, relativePriority: Int) {
        self.queue = DispatchQueue(label: name, qos: DispatchQoS(qosClass: .utility, relativePriority: relativePriority))
        super.init()
    }

    @objc(dispatchAsyncWithBlock:)
    public func dispatchAsync(_ block: @escaping () -> Void) {
        queue.async {
            autoreleasepool {
                block()
            }
        }
    }

    @objc(dispatchAsyncOnMainQueue:)
    public func dispatchAsyncOnMainQueue(block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                autoreleasepool {
                    block()
                }
            }
        }
    }
    
    @objc public func dispatchSync(block: () -> Void) {
        queue.sync(execute: block)
    }
    
    @objc(dispatchSyncOnMainQueue:)
    public func dispatchSyncOnMainQueue(block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }
    
    @objc(dispatchSyncOnMainQueue:timeout:)
    @discardableResult public func dispatchSyncOnMainQueue(block: @escaping () -> Void, timeout: TimeInterval) -> Bool {
        if Thread.isMainThread {
            block()
            return true
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                block()
                semaphore.signal()
            }
            
            let timeoutTime = DispatchTime.now() + timeout
            return semaphore.wait(timeout: timeoutTime) == .success
        }
    }

    @objc public func dispatch(after interval: TimeInterval, block: DispatchWorkItemWrapper) {
        let delta = Int64(interval * Double(NSEC_PER_SEC))
        let when = DispatchTime.now() + DispatchTimeInterval.nanoseconds(Int(delta))
        queue.asyncAfter(deadline: when) {
            autoreleasepool {
                block.workItem.perform()
            }
        }
    }
    
    @objc
    public func dispatchCancel(_ block: DispatchWorkItemWrapper) {
        block.workItem.cancel()
    }

    @objc(createDispatchBlock:)
    public func createDispatchBlock(_ block: @escaping () -> Void) -> DispatchWorkItemWrapper? {
        return .init(workItem: DispatchWorkItem(block: block))
    }
} 

// DispatchWorkItem is not visible to objc so this class wraps it
// and is used in @objc APIs.
@_spi(Private) @objc(SentryDispatchWorkItemWrapper) public class DispatchWorkItemWrapper: NSObject {
    let workItem: DispatchWorkItem
    
    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }
}
