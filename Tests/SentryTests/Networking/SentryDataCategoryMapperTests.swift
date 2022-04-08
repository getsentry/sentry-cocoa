@testable import Sentry
import XCTest

class SentryDataCategoryMapperTests: XCTestCase {

    func testEventItemType() {
        XCTAssertEqual(SentryDataCategory.error, mapEventType(eventType: "event"))
        XCTAssertEqual(SentryDataCategory.error, mapEventType(eventType: "any eventtype"))
    }

    func testEnvelopeItemType() {
        XCTAssertEqual(SentryDataCategory.error, mapEnvelopeItemType(itemType: "event"))
        XCTAssertEqual(SentryDataCategory.session, mapEnvelopeItemType(itemType: "session"))
        XCTAssertEqual(SentryDataCategory.transaction, mapEnvelopeItemType(itemType: "transaction"))
        XCTAssertEqual(SentryDataCategory.attachment, mapEnvelopeItemType(itemType: "attachment"))
        XCTAssertEqual(SentryDataCategory.default, mapEnvelopeItemType(itemType: "unkown item type"))
    }

    func testMapIntegerToCategory() {
        XCTAssertEqual(.all, DataCategoryMapper.mapInteger(toCategory: 0))
        XCTAssertEqual(.default, DataCategoryMapper.mapInteger(toCategory: 1))
        XCTAssertEqual(.error, DataCategoryMapper.mapInteger(toCategory: 2))
        XCTAssertEqual(.session, DataCategoryMapper.mapInteger(toCategory: 3))
        XCTAssertEqual(.transaction, DataCategoryMapper.mapInteger(toCategory: 4))
        XCTAssertEqual(.attachment, DataCategoryMapper.mapInteger(toCategory: 5))
        XCTAssertEqual(.userFeedback, DataCategoryMapper.mapInteger(toCategory: 6))
        XCTAssertEqual(.unknown, DataCategoryMapper.mapInteger(toCategory: 7))
    }
    
    func testMapStringToCategory() {
        XCTAssertEqual(.all, DataCategoryMapper.mapString(toCategory: ""))
        XCTAssertEqual(.default, DataCategoryMapper.mapString(toCategory: "default"))
        XCTAssertEqual(.error, DataCategoryMapper.mapString(toCategory: "error"))
        XCTAssertEqual(.session, DataCategoryMapper.mapString(toCategory: "session"))
        XCTAssertEqual(.transaction, DataCategoryMapper.mapString(toCategory: "transaction"))
        XCTAssertEqual(.attachment, DataCategoryMapper.mapString(toCategory: "attachment"))
        XCTAssertEqual(.userFeedback, DataCategoryMapper.mapString(toCategory: "user_report"))
        XCTAssertEqual(.unknown, DataCategoryMapper.mapString(toCategory: "unkown"))
    }

    private func mapEnvelopeItemType(itemType: String) -> SentryDataCategory {
        return DataCategoryMapper.mapEnvelopeItemType(toCategory: itemType)
    }

    private func mapEventType(eventType: String) -> SentryDataCategory {
        return DataCategoryMapper.mapEventType(toCategory: eventType)
    }
}
