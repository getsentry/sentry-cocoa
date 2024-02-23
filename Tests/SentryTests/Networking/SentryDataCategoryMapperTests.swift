import Nimble
@testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {
    func testEnvelopeItemType() {
        expect(sentryDataCategoryForEnvelopItemType("event")) == .error
        expect(sentryDataCategoryForEnvelopItemType("session")) == .session
        expect(sentryDataCategoryForEnvelopItemType("transaction")) == .transaction
        expect(sentryDataCategoryForEnvelopItemType("attachment")) == .attachment
        expect(sentryDataCategoryForEnvelopItemType("profile")) == .profile
        expect(sentryDataCategoryForEnvelopItemType("statsd")) == .statsd
        expect(sentryDataCategoryForEnvelopItemType("unknown item type")) == .default
    }

    func testMapIntegerToCategory() {
        expect(sentryDataCategoryForNSUInteger(0)) == .all
        expect(sentryDataCategoryForNSUInteger(1)) == .default
        expect(sentryDataCategoryForNSUInteger(2)) == .error
        expect(sentryDataCategoryForNSUInteger(3)) == .session
        expect(sentryDataCategoryForNSUInteger(4)) == .transaction
        expect(sentryDataCategoryForNSUInteger(5)) == .attachment
        expect(sentryDataCategoryForNSUInteger(6)) == .userFeedback
        expect(sentryDataCategoryForNSUInteger(7)) == .profile
        expect(sentryDataCategoryForNSUInteger(8)) == .statsd
        expect(sentryDataCategoryForNSUInteger(9)) == .unknown

        XCTAssertEqual(.unknown, sentryDataCategoryForNSUInteger(10), "Failed to map unknown category number to case .unknown")
    }
    
    func testMapStringToCategory() {
        expect(sentryDataCategoryForString(kSentryDataCategoryNameAll)) == .all
        expect(sentryDataCategoryForString(kSentryDataCategoryNameDefault)) == .default
        expect(sentryDataCategoryForString(kSentryDataCategoryNameError)) == .error
        expect(sentryDataCategoryForString(kSentryDataCategoryNameSession)) == .session
        expect(sentryDataCategoryForString(kSentryDataCategoryNameTransaction)) == .transaction
        expect(sentryDataCategoryForString(kSentryDataCategoryNameAttachment)) == .attachment
        expect(sentryDataCategoryForString(kSentryDataCategoryNameUserFeedback)) == .userFeedback
        expect(sentryDataCategoryForString(kSentryDataCategoryNameProfile)) == .profile
        expect(sentryDataCategoryForString(kSentryDataCategoryNameStatsd)) == .statsd
        expect(sentryDataCategoryForString(kSentryDataCategoryNameUnknown)) == .unknown

        XCTAssertEqual(.unknown, sentryDataCategoryForString("gdfagdfsa"), "Failed to map unknown category name to case .unknown")
    }

    func testMapCategoryToString() {
        expect(nameForSentryDataCategory(.all)) == kSentryDataCategoryNameAll
        expect(nameForSentryDataCategory(.default)) == kSentryDataCategoryNameDefault
        expect(nameForSentryDataCategory(.error)) == kSentryDataCategoryNameError
        expect(nameForSentryDataCategory(.session)) == kSentryDataCategoryNameSession
        expect(nameForSentryDataCategory(.transaction)) == kSentryDataCategoryNameTransaction
        expect(nameForSentryDataCategory(.attachment)) == kSentryDataCategoryNameAttachment
        expect(nameForSentryDataCategory(.userFeedback)) == kSentryDataCategoryNameUserFeedback
        expect(nameForSentryDataCategory(.profile)) == kSentryDataCategoryNameProfile
        expect(nameForSentryDataCategory(.statsd)) == kSentryDataCategoryNameStatsd
        expect(nameForSentryDataCategory(.unknown)) == kSentryDataCategoryNameUnknown
    }
}
