@_spi(Private) @testable import Sentry
import XCTest

final class SentryOptionsTests: XCTestCase {

    // MARK: - Data Collection

    func testDataCollection_whenInitialized_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = Options()

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testDataCollection_whenSet_shouldRetainValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let options = Options()

        // -- Act --
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
        #endif
    }

    // MARK: - Data Collection Dictionary Decoding

    func testInitWithDictionary_whenDataCollectionIsAbsent_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsEmpty_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": [:]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": "off"
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": NSNull()
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenDataCollectionIsPresent_shouldSetDataCollection() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "dataCollection": [
                "userInfo": false,
                "graphql": ["variables": false],
                "database": ["urlQueryParams": false],
                "frameContextLines": 0
            ]
        ]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
        XCTAssertFalse(options.dataCollection.graphql.variables)
        XCTAssertFalse(options.dataCollection.database.urlQueryParams)
        XCTAssertEqual(options.dataCollection.frameContextLines, 0)
        #endif
    }
}
