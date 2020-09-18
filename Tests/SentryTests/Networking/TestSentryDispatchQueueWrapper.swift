import Foundation

class TestSentryDispatchQueueWrapper: SentryDispatchQueueWrapper {
    override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }
}
