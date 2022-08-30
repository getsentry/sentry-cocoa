@testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {
    func testEnvelopeItemType() {
        XCTAssertEqual(.error, categoryForEnvelopItemType("event"))
        XCTAssertEqual(.session, categoryForEnvelopItemType("session"))
        XCTAssertEqual(.transaction, categoryForEnvelopItemType("transaction"))
        XCTAssertEqual(.attachment, categoryForEnvelopItemType("attachment"))
        XCTAssertEqual(.profile, categoryForEnvelopItemType("profile"))
        XCTAssertEqual(.default, categoryForEnvelopItemType("unknown item type"))
    }

    func testMapIntegerToCategory() {
        XCTAssertEqual(.all, categoryForNSUInteger(0))
        XCTAssertEqual(.default, categoryForNSUInteger(1))
        XCTAssertEqual(.error, categoryForNSUInteger(2))
        XCTAssertEqual(.session, categoryForNSUInteger(3))
        XCTAssertEqual(.transaction, categoryForNSUInteger(4))
        XCTAssertEqual(.attachment, categoryForNSUInteger(5))
        XCTAssertEqual(.userFeedback, categoryForNSUInteger(6))
        XCTAssertEqual(.profile, categoryForNSUInteger(7))
        XCTAssertEqual(.unknown, categoryForNSUInteger(8))

        XCTAssertEqual(.unknown, categoryForNSUInteger(9), "Failed to map unknown category number to case .unknown")
    }
    
    func testMapStringToCategory() {
        XCTAssertEqual(.all, categoryForString(kSentryDataCategoryNameAll))
        XCTAssertEqual(.default, categoryForString(kSentryDataCategoryNameDefault))
        XCTAssertEqual(.error, categoryForString(kSentryDataCategoryNameError))
        XCTAssertEqual(.session, categoryForString(kSentryDataCategoryNameSession))
        XCTAssertEqual(.transaction, categoryForString(kSentryDataCategoryNameTransaction))
        XCTAssertEqual(.attachment, categoryForString(kSentryDataCategoryNameAttachment))
        XCTAssertEqual(.userFeedback, categoryForString(kSentryDataCategoryNameUserFeedback))
        XCTAssertEqual(.profile, categoryForString(kSentryDataCategoryNameProfile))
        XCTAssertEqual(.unknown, categoryForString(kSentryDataCategoryNameUnknown))

        XCTAssertEqual(.unknown, categoryForString("gdfagdfsa"), "Failed to map unknown category name to case .unknown")
    }

    func testMapCategoryToString() {
        XCTAssertEqual(kSentryDataCategoryNameAll, nameForCategory(.all))
        XCTAssertEqual(kSentryDataCategoryNameDefault, nameForCategory(.default))
        XCTAssertEqual(kSentryDataCategoryNameError, nameForCategory(.error))
        XCTAssertEqual(kSentryDataCategoryNameSession, nameForCategory(.session))
        XCTAssertEqual(kSentryDataCategoryNameTransaction, nameForCategory(.transaction))
        XCTAssertEqual(kSentryDataCategoryNameAttachment, nameForCategory(.attachment))
        XCTAssertEqual(kSentryDataCategoryNameUserFeedback, nameForCategory(.userFeedback))
        XCTAssertEqual(kSentryDataCategoryNameProfile, nameForCategory(.profile))
        XCTAssertEqual(kSentryDataCategoryNameUnknown, nameForCategory(.unknown))
    }
}
