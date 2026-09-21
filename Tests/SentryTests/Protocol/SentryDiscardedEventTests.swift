#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) import Sentry
#endif
import XCTest

class SentryDiscardedEventTests: XCTestCase {

    func testSerialize() {
        // -- Arrange --
        let discardedEvent = SentryDiscardedEvent(reason: SentryDiscardReason.sampleRate.name, category: SentryDataCategory.transaction.name, quantity: 2)

        // -- Act --
        let actual = discardedEvent.serialize()

        // -- Assert --
        XCTAssertEqual("sample_rate", actual["reason"] as? String)
        XCTAssertEqual("transaction", actual["category"] as? String)
        XCTAssertEqual(discardedEvent.quantity, actual["quantity"] as? UInt)
    }
}
