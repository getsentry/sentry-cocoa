import Foundation
import Sentry

public class TestDispatchFactory: SentryDispatchFactory {
    public var vendedSourceHandler: ((TestDispatchSourceWrapper) -> Void)?
    public var vendedQueueHandler: ((TestSentryDispatchQueueWrapper) -> Void)?

    public override func queue(withName name: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr) -> SentryDispatchQueueWrapper {
        let queue = TestSentryDispatchQueueWrapper(name: name, attributes: attributes)
        vendedQueueHandler?(queue)
        return queue
    }

    public override func source(withInterval interval: UInt64, leeway: UInt64, queueName: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr, eventHandler: @escaping () -> Void) -> SentryDispatchSourceWrapper {
        let source = TestDispatchSourceWrapper(eventHandler: eventHandler)
        vendedSourceHandler?(source)
        return source
    }
}
