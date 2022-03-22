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
        XCTAssertEqual(SentryDataCategory.all, DataCategoryMapper.mapInteger(toCategory: 0))
        XCTAssertEqual(SentryDataCategory.default, DataCategoryMapper.mapInteger(toCategory: 1))
        XCTAssertEqual(SentryDataCategory.error, DataCategoryMapper.mapInteger(toCategory: 2))
        XCTAssertEqual(SentryDataCategory.session, DataCategoryMapper.mapInteger(toCategory: 3))
        XCTAssertEqual(SentryDataCategory.transaction, DataCategoryMapper.mapInteger(toCategory: 4))
        XCTAssertEqual(SentryDataCategory.attachment, DataCategoryMapper.mapInteger(toCategory: 5))
        XCTAssertEqual(SentryDataCategory.unknown, DataCategoryMapper.mapInteger(toCategory: 6))
        XCTAssertEqual(SentryDataCategory.unknown, DataCategoryMapper.mapInteger(toCategory: 7))
    }

    private func mapEnvelopeItemType(itemType: String) -> SentryDataCategory {
        return DataCategoryMapper.mapEnvelopeItemType(toCategory: itemType)
    }

    private func mapEventType(eventType: String) -> SentryDataCategory {
        return DataCategoryMapper.mapEventType(toCategory: eventType)
    }
}
