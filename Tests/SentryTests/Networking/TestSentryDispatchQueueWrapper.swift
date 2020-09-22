import Foundation

class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {
    override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }
    
    override func dispatchOnce(_ predicate: UnsafeMutablePointer<Int>, block: @escaping () -> Void) {
        block()
    }
}
