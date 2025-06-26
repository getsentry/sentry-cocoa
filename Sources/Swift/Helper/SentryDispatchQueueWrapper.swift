@_implementationOnly import _SentryPrivate

// This is the Swift verion of `_SentryDispatchQueueWrapperInternal`
// It exists to allow the implementation of `_SentryDispatchQueueWrapperInternal`
// to be accessible to Swift without making that header file public
@objcMembers @_spi(Private) public class SentryDispatchQueueWrapper: NSObject {
    
    private let internalWrapper: _SentryDispatchQueueWrapperInternal
    
    public override init() {
        internalWrapper = _SentryDispatchQueueWrapperInternal()
    }
    
    public init(name: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr?) {
        internalWrapper = _SentryDispatchQueueWrapperInternal(name: name, attributes: attributes)
    }
    
    public var queue: DispatchQueue {
        internalWrapper.queue
    }

    @objc(dispatchAsyncWithBlock:)
    public func dispatchAsync(_ block: @escaping () -> Void) {
        internalWrapper.dispatchAsync(block)
    }
    
    func dispatchSync(_ block: @escaping () -> Void) {
        internalWrapper.dispatchSync(block)
    }
    
    @objc(dispatchAsyncOnMainQueue:)
    public func dispatchAsyncOnMainQueue(block: @escaping () -> Void) {
        internalWrapper.dispatchAsyncOnMainQueue(block: block)
    }

    @objc(dispatchSyncOnMainQueue:)
    public func dispatchSyncOnMainQueue(block: @escaping () -> Void) {
        internalWrapper.dispatchSyncOnMainQueue(block: block)
    }
    
    public func dispatchSyncOnMainQueue(_ block: @escaping () -> Void, timeout: Double) {
        internalWrapper.dispatchSync(onMainQueue: block, timeout: timeout)
    }

    func dispatch(after interval: TimeInterval, block: SentryDispatchBlockWrapper) {
        internalWrapper.dispatch(after: interval, block: block)
    }

    func dispatchCancel(_ block: SentryDispatchBlockWrapper) {
        internalWrapper.dispatchCancel(block)
    }

    public func dispatchOnce(_ predicate: UnsafeMutablePointer<CLong>, block: @escaping () -> Void) {
        internalWrapper.dispatchOnce(predicate, block: block)
    }
    
    func createDispatchBlock(_ block: @escaping () -> Void) -> SentryDispatchBlockWrapper? {
        internalWrapper.createDispatchBlock(block)
    }
}
