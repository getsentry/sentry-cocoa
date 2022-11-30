import Foundation

/// A wrapper around `SentryDispatchQueueWrapper` that memoized invocations to its methods and allows customization of async logic, specifically: dispatch-after calls can be made to run immediately, or not at all.
class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {

    var dispatchAsyncCalled = 0

    /// Whether or not delayed dispatches should execute.
    /// - SeeAlso: `delayDispatches`, which controls whether the block should execute immediately or with the requested delay.
    var dispatchAfterExecutesBlock = false

    /// If `true`, delay dispatched block execution by the specified duration. Be sure to set expectations in test code that relies on delayed dispatches.
    var delayDispatches = false

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
            if dispatchAfterExecutesBlock {
                if delayDispatches {
                    DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: .init(block: block))
                } else {
                    block()
                }
            }
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
