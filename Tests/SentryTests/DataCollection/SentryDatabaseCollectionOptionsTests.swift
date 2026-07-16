@_spi(Private) @testable import Sentry
import XCTest

class SentryDatabaseCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions()

        // -- Assert --
        XCTAssertTrue(options.queryParams)
        #endif
    }

    func testInit_withArguments_shouldSetProperties() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(queryParams: false)

        // -- Assert --
        XCTAssertFalse(options.queryParams)
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenQueryParamsIsPresent_shouldSetQueryParams() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": false]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.queryParams)
        #endif
    }

    func testInitWithDictionary_whenQueryParamsIsMissing_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
        #endif
    }

    func testInitWithDictionary_whenQueryParamsIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": NSNull()]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
        #endif
    }

    func testInitWithDictionary_whenQueryParamsHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["queryParams": "false"]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
        #endif
    }
}
