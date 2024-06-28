@testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {
    
    func testEnvelopeItemType() {
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("event"), .error)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("session"), .session)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("transaction"), .transaction)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("attachment"), .attachment)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("profile"), .profile)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("profile_chunk"), .profileChunk)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("statsd"), .metricBucket)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("replay_video"), .replay)
        XCTAssertEqual(sentryDataCategoryForEnvelopItemType("unknown item type"), .default)
    }

    func testMapIntegerToCategory() {
        XCTAssertEqual(sentryDataCategoryForNSUInteger(0), .all)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(1), .default)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(2), .error)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(3), .session)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(4), .transaction)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(5), .attachment)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(6), .userFeedback)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(7), .profile)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(8), .metricBucket)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(9), .replay)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(10), .profileChunk)
        XCTAssertEqual(sentryDataCategoryForNSUInteger(11), .unknown)

        XCTAssertEqual(.unknown, sentryDataCategoryForNSUInteger(11), "Failed to map unknown category number to case .unknown")
    }
    
    func testMapStringToCategory() {
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameAll), .all)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameDefault), .default)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameError), .error)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameSession), .session)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameTransaction), .transaction)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameAttachment), .attachment)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameUserFeedback), .userFeedback)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameProfile), .profile)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameProfileChunk), .profileChunk)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameMetricBucket), .metricBucket)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameReplay), .replay)
        XCTAssertEqual(sentryDataCategoryForString(kSentryDataCategoryNameUnknown), .unknown)

        XCTAssertEqual(.unknown, sentryDataCategoryForString("gdfagdfsa"), "Failed to map unknown category name to case .unknown")
    }

    func testMapCategoryToString() {
        XCTAssertEqual(nameForSentryDataCategory(.all), kSentryDataCategoryNameAll)
        XCTAssertEqual(nameForSentryDataCategory(.default), kSentryDataCategoryNameDefault)
        XCTAssertEqual(nameForSentryDataCategory(.error), kSentryDataCategoryNameError)
        XCTAssertEqual(nameForSentryDataCategory(.session), kSentryDataCategoryNameSession)
        XCTAssertEqual(nameForSentryDataCategory(.transaction), kSentryDataCategoryNameTransaction)
        XCTAssertEqual(nameForSentryDataCategory(.attachment), kSentryDataCategoryNameAttachment)
        XCTAssertEqual(nameForSentryDataCategory(.userFeedback), kSentryDataCategoryNameUserFeedback)
        XCTAssertEqual(nameForSentryDataCategory(.profile), kSentryDataCategoryNameProfile)
        XCTAssertEqual(nameForSentryDataCategory(.profileChunk), kSentryDataCategoryNameProfileChunk)
        XCTAssertEqual(nameForSentryDataCategory(.metricBucket), kSentryDataCategoryNameMetricBucket)
        XCTAssertEqual(nameForSentryDataCategory(.replay), kSentryDataCategoryNameReplay)
        XCTAssertEqual(nameForSentryDataCategory(.unknown), kSentryDataCategoryNameUnknown)
    }
}
