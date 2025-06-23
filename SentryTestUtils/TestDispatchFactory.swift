import _SentryPrivate
import Foundation

public class TestDispatchFactory: SentryDispatchFactory {
    public var vendedSourceHandler: ((TestDispatchSourceWrapper) -> Void)?
    public var vendedQueueHandler: ((TestSentryDispatchQueueWrapper) -> Void)?

    public var createUtilityQueueInvocations = Invocations<(name: String, relativePriority: Int32)>()

    public override func queue(withName name: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr) -> SentryDispatchQueueWrapper {
        let queue = TestSentryDispatchQueueWrapper(name: name, attributes: attributes)
        vendedQueueHandler?(queue)
        return queue
    }

    public override func createUtilityQueue(_ name: UnsafePointer<CChar>, relativePriority: Int32) -> SentryDispatchQueueWrapper {
        createUtilityQueueInvocations.record((String(cString: name), relativePriority))
        // Due to the absense of `dispatch_queue_attr_make_with_qos_class` in Swift, we do not pass any attributes.
        // This will not affect the tests as they do not need an actual low priority queue.
        return TestSentryDispatchQueueWrapper(name: name, attributes: nil)
    }

    public override func source(withInterval interval: UInt64, leeway: UInt64, queueName: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr, eventHandler: @escaping () -> Void) -> SentryDispatchSourceWrapper {
        let source = TestDispatchSourceWrapper(eventHandler: eventHandler)
        vendedSourceHandler?(source)
        return source
    }
}
