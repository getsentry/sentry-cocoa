@_spi(Private) @testable import Sentry
import XCTest

class SentryDatabaseCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() {
        let options = SentryDataCollection.DatabaseCollectionOptions()
        XCTAssertTrue(options.queryParams)
    }

    func testInit_withArguments_shouldSetProperties() {
        let options = SentryDataCollection.DatabaseCollectionOptions(queryParams: false)
        XCTAssertFalse(options.queryParams)
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenQueryParamsIsPresent_shouldSetQueryParams() {
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": false]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.queryParams)
    }

    func testInitWithDictionary_whenQueryParamsIsMissing_shouldUseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
    }

    func testInitWithDictionary_whenQueryParamsIsNSNull_shouldUseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": NSNull()]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
    }

    func testInitWithDictionary_whenQueryParamsHasWrongType_shouldUseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": "false"]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
    }
}
