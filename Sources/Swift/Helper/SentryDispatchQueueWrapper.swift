@_implementationOnly import _SentryPrivate

// This is the Swift verion of `_SentryDispatchQueueWrapperInternal`
// It exists to allow the implementation of `_SentryDispatchQueueWrapperInternal`
// to be accessible to Swift without making that header file public
@objcMembers @_spi(Private) public class SentryDispatchQueueWrapper: NSObject {
    
    let internalWrapper: _SentryDispatchQueueWrapperInternal
    
    public override init() {
        internalWrapper = _SentryDispatchQueueWrapperInternal()
    }
    
    public init(name: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr?) {
        internalWrapper = _SentryDispatchQueueWrapperInternal(name: name, attributes: attributes)
    }
    
    public var queue: DispatchQueue {
        internalWrapper.queue
    }
    
    func dispatchAsync(_ block: @escaping () -> Void) {
        internalWrapper.dispatchAsync(block)
    }
    
    func dispatchSync(_ block: @escaping () -> Void) {
        internalWrapper.dispatchSync(block)
    }
    
    @objc(dispatchAsyncOnMainQueue:)
    func dispatchAsyncOnMainQueue(block: @escaping () -> Void) {
        internalWrapper.dispatchAsyncOnMainQueue(block: block)
    }
    
    func dispatchAsyncWithBlock(_ block: @escaping () -> Void) {
        internalWrapper.dispatchAsync(block)
    }

    @objc(dispatchSyncOnMainQueue:)
    func dispatchSyncOnMainQueue(block: @escaping () -> Void) {
        internalWrapper.dispatchSyncOnMainQueue(block: block)
    }
    
    func dispatchSyncOnMainQueue(_ block: @escaping () -> Void, timeout: Double) {
        internalWrapper.dispatchSync(onMainQueue: block, timeout: timeout)
    }

    func dispatch(after interval: TimeInterval, block: @escaping () -> Void) {
        internalWrapper.dispatch(after: interval, block: block)
    }

    func dispatchCancel(_ block: @escaping () -> Void) {
        internalWrapper.dispatchCancel(block)
    }

    func dispatchOnce(_ predicate: UnsafeMutablePointer<CLong>, block: @escaping () -> Void) {
        internalWrapper.dispatchOnce(predicate, block: block)
    }
    
    func createDispatchBlock(_ block: @escaping () -> Void) -> (() -> Void)? {
        internalWrapper.createDispatchBlock(block)
    }
}
