import _SentryPrivate
import Foundation
@_spi(Private) import Sentry

@_spi(Private) public class TestDispatchFactory: SentryDispatchFactory {
    public var vendedSourceHandler: ((TestDispatchSourceWrapper) -> Void)?

    public var createUtilityQueueInvocations = Invocations<(name: String, relativePriority: Int32)>()

    public override func createLowPriorityQueue(_ name: String, relativePriority: Int32) -> SentryDispatchQueueWrapper {
        createLowPriorityQueueInvocations.record((name, relativePriority))
        return TestSentryDispatchQueueWrapper(utilityNamed: name, relativePriority: Int(relativePriority))
    }

    public override func source(withInterval interval: UInt64, leeway: UInt64, concurrentQueueName: String, eventHandler: @escaping () -> Void) -> SentryDispatchSourceWrapper {
        let source = TestDispatchSourceWrapper(eventHandler: eventHandler)
        vendedSourceHandler?(source)
        return source
    }
}
