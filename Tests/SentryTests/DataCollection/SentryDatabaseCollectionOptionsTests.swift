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
        XCTAssertTrue(options.urlQueryParams)
        #endif
    }

    func testInit_withArguments_shouldSetProperties() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(urlQueryParams: false)

        // -- Assert --
        XCTAssertFalse(options.urlQueryParams)
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenurlQueryParamsIsPresent_shouldSeturlQueryParams() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["urlQueryParams": false]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.urlQueryParams)
        #endif
    }

    func testInitWithDictionary_whenurlQueryParamsIsMissing_shouldUseDefault() throws {
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

    func testInitWithDictionary_whenurlQueryParamsIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["urlQueryParams": NSNull()]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
        #endif
    }

    func testInitWithDictionary_whenurlQueryParamsHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["urlQueryParams": "false"]

        // -- Act --
        let options = SentryDataCollection.DatabaseCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.DatabaseCollectionOptions())
        #endif
    }
}
