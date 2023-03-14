import Foundation

/// A wrapper around `SentryDispatchQueueWrapper` that memoized invocations to its methods and allows customization of async logic, specifically: dispatch-after calls can be made to run immediately, or not at all.
public class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {

    public var dispatchAsyncCalled = 0

    /// Whether or not delayed dispatches should execute.
    /// - SeeAlso: `delayDispatches`, which controls whether the block should execute immediately or with the requested delay.
    public var dispatchAfterExecutesBlock = false

    public var dispatchAsyncInvocations = Invocations<() -> Void>()
    public var dispatchAsyncExecutesBlock = true
    public override func dispatchAsync(_ block: @escaping () -> Void) {
        dispatchAsyncCalled += 1
        dispatchAsyncInvocations.record(block)
        if dispatchAsyncExecutesBlock {
            block()
        }
    }
    
    public func invokeLastDispatchAsync() {
        dispatchAsyncInvocations.invocations.last?()
    }
    
    public var blockOnMainInvocations = Invocations<() -> Void>()
    public var blockBeforeMainBlock: () -> Bool = { true }

    public override func dispatchAsync(onMainQueue block: @escaping () -> Void) {
        blockOnMainInvocations.record(block)
        if blockBeforeMainBlock() {
            block()
        }
    }

    public override func dispatchSync(onMainQueue block: @escaping () -> Void) {
        blockOnMainInvocations.record(block)
        if blockBeforeMainBlock() {
            block()
        }
    }

    public var dispatchAfterInvocations = Invocations<(interval: TimeInterval, block: () -> Void)>()
    public override func dispatch(after interval: TimeInterval, block: @escaping () -> Void) {
        dispatchAfterInvocations.record((interval, block))
        if blockBeforeMainBlock() {
            if dispatchAfterExecutesBlock {
                block()
            }
        }
    }

    public func invokeLastDispatchAfter() {
        dispatchAfterInvocations.invocations.last?.block()
    }

    public var dispatchCancelInvocations = Invocations<() -> Void>()
    public override func dispatchCancel(_ block: @escaping () -> Void) {
        dispatchCancelInvocations.record(block)
    }

    public override func dispatchOnce(_ predicate: UnsafeMutablePointer<Int>, block: @escaping () -> Void) {
        block()
    }
}
