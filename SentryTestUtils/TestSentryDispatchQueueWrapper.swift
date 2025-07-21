import _SentryPrivate
import Foundation
@_spi(Private) @testable import Sentry

/// A wrapper around `SentryDispatchQueueWrapper` that memoized invocations to its methods and allows customization of async logic, specifically: dispatch-after calls can be made to run immediately, or not at all.
@_spi(Private) public final class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {

    private let dispatchAsyncLock = NSLock()
    
    public var dispatchAsyncCalled = 0

    /// Whether or not delayed dispatches should execute.
    /// - SeeAlso: `delayDispatches`, which controls whether the block should execute immediately or with the requested delay.
    public var dispatchAfterExecutesBlock = false

    public var dispatchAsyncInvocations = Invocations<() -> Void>()
    public var dispatchAsyncExecutesBlock = true
    public override func dispatchAsync(_ block: @escaping () -> Void) {
        
        dispatchAsyncLock.synchronized {
            dispatchAsyncCalled += 1
            dispatchAsyncInvocations.record(block)
        }
        
        if dispatchAsyncExecutesBlock {
            block()
        }
    }
    
    public func invokeLastDispatchAsync() {
        dispatchAsyncInvocations.invocations.last?()
    }
    
    public var blockOnMainInvocations = Invocations<() -> Void>()
    public var blockBeforeMainBlock: () -> Bool = { true }

    public override func dispatchAsyncOnMainQueue(block: @escaping () -> Void) {
        blockOnMainInvocations.record(block)
        if blockBeforeMainBlock() {
            block()
        }
    }

    public override func dispatchSyncOnMainQueue(block: @escaping () -> Void) {
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

    public var dispatchAfterWorkItemInvocations = Invocations<(interval: TimeInterval, workItem: DispatchWorkItem)>()
    public override func dispatch(after interval: TimeInterval, workItem: DispatchWorkItem) {
        dispatchAfterWorkItemInvocations.record((interval, workItem))
        if blockBeforeMainBlock() {
            if dispatchAfterExecutesBlock {
                workItem.perform()
            }
        }
    }

    public func invokeLastDispatchAfterWorkItem() {
        dispatchAfterWorkItemInvocations.invocations.last?.workItem.perform()
    }

    public var dispatchCancelInvocations = 0
    public override var shouldDispatchCancel: Bool {
        dispatchCancelInvocations += 1
        return false
    }

    public override func dispatchOnce(_ predicate: UnsafeMutablePointer<Int>, block: @escaping () -> Void) {
        block()
    }
    
    public var createDispatchBlockReturnsNULL = false
    public override var shouldCreateDispatchBlock: Bool {
        !createDispatchBlockReturnsNULL
    }
    
}
