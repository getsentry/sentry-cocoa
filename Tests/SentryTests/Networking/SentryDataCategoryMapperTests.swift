@testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {
    func testEnvelopeItemType() {
        XCTAssertEqual(.error, sentryDataCategoryForEnvelopItemType("event"))
        XCTAssertEqual(.session, sentryDataCategoryForEnvelopItemType("session"))
        XCTAssertEqual(.transaction, sentryDataCategoryForEnvelopItemType("transaction"))
        XCTAssertEqual(.attachment, sentryDataCategoryForEnvelopItemType("attachment"))
        XCTAssertEqual(.profile, sentryDataCategoryForEnvelopItemType("profile"))
        XCTAssertEqual(.default, sentryDataCategoryForEnvelopItemType("unknown item type"))
        XCTAssertEqual(.replay, sentryDataCategoryForEnvelopItemType("replay_video"))
    }

    func testMapIntegerToCategory() {
        XCTAssertEqual(.all, sentryDataCategoryForNSUInteger(0))
        XCTAssertEqual(.default, sentryDataCategoryForNSUInteger(1))
        XCTAssertEqual(.error, sentryDataCategoryForNSUInteger(2))
        XCTAssertEqual(.session, sentryDataCategoryForNSUInteger(3))
        XCTAssertEqual(.transaction, sentryDataCategoryForNSUInteger(4))
        XCTAssertEqual(.attachment, sentryDataCategoryForNSUInteger(5))
        XCTAssertEqual(.userFeedback, sentryDataCategoryForNSUInteger(6))
        XCTAssertEqual(.profile, sentryDataCategoryForNSUInteger(7))
        XCTAssertEqual(.replay, sentryDataCategoryForNSUInteger(8))
        XCTAssertEqual(.unknown, sentryDataCategoryForNSUInteger(9))
        XCTAssertEqual(.unknown, sentryDataCategoryForNSUInteger(10), "Failed to map unknown category number to case .unknown")
    }
    
    func testMapStringToCategory() {
        XCTAssertEqual(.all, sentryDataCategoryForString(kSentryDataCategoryNameAll))
        XCTAssertEqual(.default, sentryDataCategoryForString(kSentryDataCategoryNameDefault))
        XCTAssertEqual(.error, sentryDataCategoryForString(kSentryDataCategoryNameError))
        XCTAssertEqual(.session, sentryDataCategoryForString(kSentryDataCategoryNameSession))
        XCTAssertEqual(.transaction, sentryDataCategoryForString(kSentryDataCategoryNameTransaction))
        XCTAssertEqual(.attachment, sentryDataCategoryForString(kSentryDataCategoryNameAttachment))
        XCTAssertEqual(.userFeedback, sentryDataCategoryForString(kSentryDataCategoryNameUserFeedback))
        XCTAssertEqual(.profile, sentryDataCategoryForString(kSentryDataCategoryNameProfile))
        XCTAssertEqual(.unknown, sentryDataCategoryForString(kSentryDataCategoryNameUnknown))

        XCTAssertEqual(.unknown, sentryDataCategoryForString("gdfagdfsa"), "Failed to map unknown category name to case .unknown")
    }

    func testMapCategoryToString() {
        XCTAssertEqual(kSentryDataCategoryNameAll, nameForSentryDataCategory(.all))
        XCTAssertEqual(kSentryDataCategoryNameDefault, nameForSentryDataCategory(.default))
        XCTAssertEqual(kSentryDataCategoryNameError, nameForSentryDataCategory(.error))
        XCTAssertEqual(kSentryDataCategoryNameSession, nameForSentryDataCategory(.session))
        XCTAssertEqual(kSentryDataCategoryNameTransaction, nameForSentryDataCategory(.transaction))
        XCTAssertEqual(kSentryDataCategoryNameAttachment, nameForSentryDataCategory(.attachment))
        XCTAssertEqual(kSentryDataCategoryNameUserFeedback, nameForSentryDataCategory(.userFeedback))
        XCTAssertEqual(kSentryDataCategoryNameProfile, nameForSentryDataCategory(.profile))
        XCTAssertEqual(kSentryDataCategoryNameUnknown, nameForSentryDataCategory(.unknown))
    }
}
