@_spi(Private) import Sentry
import XCTest

class SentryDiscardedEventTests: XCTestCase {

    func testSerialize() {
        let discardedEvent = SentryDiscardedEvent(reason: nameForSentryDiscardReason(.sampleRate), category: nameForSentryDataCategory(.transaction), quantity: 2)
        
        let actual = discardedEvent.serialize()
        
        XCTAssertEqual("sample_rate", actual["reason"] as? String)
        XCTAssertEqual("transaction", actual["category"] as? String)
        XCTAssertEqual(discardedEvent.quantity, actual["quantity"] as? UInt)
    }
}
