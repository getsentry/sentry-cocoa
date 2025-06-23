import _SentryPrivate
import Foundation
@_spi(Private) import Sentry

@_spi(Private) public class TestDispatchFactory: SentryDispatchFactory {
    public var vendedSourceHandler: ((TestDispatchSourceWrapper) -> Void)?

    public var createUtilityQueueInvocations = Invocations<(name: String, relativePriority: Int32)>()

    public override func createUtilityQueue(_ name: UnsafePointer<CChar>, relativePriority: Int32) -> SentryDispatchQueueWrapper {
        createUtilityQueueInvocations.record((String(cString: name), relativePriority))
        return TestSentryDispatchQueueWrapper(utilityNamed: String(cString: name), relativePriority: Int(relativePriority))
    }

    public override func source(withInterval interval: UInt64, leeway: UInt64, queueName: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr, eventHandler: @escaping () -> Void) -> SentryDispatchSourceWrapper {
        let source = TestDispatchSourceWrapper(eventHandler: eventHandler)
        vendedSourceHandler?(source)
        return source
    }
}
