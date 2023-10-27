import Sentry
import SentryTestUtils
import XCTest

class SentryClientReportTests: XCTestCase {

    func testSerialize() {
        SentryDependencyContainer.sharedInstance().dateProvider = TestCurrentDateProvider()
        
        let event1 = SentryDiscardedEvent(reason: .sampleRate, category: .transaction, quantity: 2)
        let event2 = SentryDiscardedEvent(reason: .beforeSend, category: .transaction, quantity: 3)
        let event3 = SentryDiscardedEvent(reason: .rateLimitBackoff, category: .error, quantity: 1)
        
        let report = SentryClientReport(discardedEvents: [event1, event2, event3])
        
        let actual = report.serialize()
        
        XCTAssertEqual(SentryDependencyContainer.sharedInstance().dateProvider.date().timeIntervalSince1970, actual["timestamp"] as? TimeInterval)
        
        let discardedEvents = actual["discarded_events"] as! [[String: Any]]
        
        func assertEvent(event: [String: Any], reason: String, category: String, quantity: UInt) {
            XCTAssertEqual(reason, event["reason"] as? String)
            XCTAssertEqual(category, event["category"] as? String)
            XCTAssertEqual(quantity, event["quantity"] as? UInt)
        }
        assertEvent(event: discardedEvents[0], reason: "sample_rate", category: "transaction", quantity: event1.quantity)
        assertEvent(event: discardedEvents[1], reason: "before_send", category: "transaction", quantity: event2.quantity)
        assertEvent(event: discardedEvents[2], reason: "ratelimit_backoff", category: "error", quantity: event3.quantity)
    }
}
