import Foundation

class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {
    
    var dispatchAsyncCalled = 0
    
    override func dispatchAsync(_ block: @escaping () -> Void) {
        dispatchAsyncCalled += 1
        block()
    }
    
    override func dispatchOnce(_ predicate: UnsafeMutablePointer<Int>, block: @escaping () -> Void) {
        block()
    }
}
