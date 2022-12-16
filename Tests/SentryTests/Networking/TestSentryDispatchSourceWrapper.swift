import Foundation

class TestSentryDispatchSourceFactory: SentryDispatchSourceFactory {
    override func dispatchSource(withType type: __dispatch_source_type_t, handle: UInt, mask: UInt, queue sourceQueue: DispatchQueue?) -> SentryDispatchSourceWrapper {
        return TestSentryDispatchSourceWrapper()
    }
}

class TestSentryDispatchSourceWrapper: SentryDispatchSourceWrapper {
    var data: UInt!
    var handler: (() -> Void)?

    override func getData() -> UInt {
        return data
    }

    override func resume(handler: @escaping () -> Void) {
        self.handler = handler
    }

    override func invalidate() {
        // no-op
    }

    func fire() {
        handler?()
    }
}
