import Foundation

class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {
    
    var dispatchAsyncCalled = 0
    
    override func dispatchAsync(_ block: @escaping () -> Void) {
        dispatchAsyncCalled += 1
        block()
    }
    
    var blockOnMainInvocations = Invocations<() -> Void>()
    var blockBeforeMainBlock: () -> Bool = { true }
    
    override func dispatchAsync(onMainQueue block: @escaping () -> Void) {
        blockOnMainInvocations.record(block)
        if blockBeforeMainBlock() {
            block()
        }
    }

    override func dispatchSync(onMainQueue block: @escaping () -> Void) {
        blockOnMainInvocations.record(block)
        if blockBeforeMainBlock() {
            block()
        }
    }
    
    var dispatchAfterInvocations = Invocations<(interval: TimeInterval, block: () -> Void)>()
    override func dispatch(after interval: TimeInterval, block: @escaping () -> Void) {
        dispatchAfterInvocations.record((interval, block))
        if blockBeforeMainBlock() {
            block()
        }
    }
    
    func invokeLastDispatchAfter() {
        dispatchAfterInvocations.invocations.last?.block()
    }
    
    var dispatchCancelInvocations = Invocations<() -> Void>()
    override func dispatchCancel(_ block: @escaping () -> Void) {
        dispatchCancelInvocations.record(block)
    }
    
    override func dispatchOnce(_ predicate: UnsafeMutablePointer<Int>, block: @escaping () -> Void) {
        block()
    }
}
