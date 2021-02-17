import XCTest

class SentryLevelMapperTests: XCTestCase {

    func testMapLevels() {
        XCTAssertEqual(SentryLevel.error, SentryLevelMapper.level(with: ""))
        XCTAssertEqual(SentryLevel.none, SentryLevelMapper.level(with: "none"))
        XCTAssertEqual(SentryLevel.debug, SentryLevelMapper.level(with: "debug"))
        XCTAssertEqual(SentryLevel.info, SentryLevelMapper.level(with: "info"))
        XCTAssertEqual(SentryLevel.warning, SentryLevelMapper.level(with: "warning"))
        XCTAssertEqual(SentryLevel.error, SentryLevelMapper.level(with: "error"))
        XCTAssertEqual(SentryLevel.fatal, SentryLevelMapper.level(with: "fatal"))
    }

}
