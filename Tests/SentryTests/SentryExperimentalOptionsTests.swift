@_spi(Private) @testable import Sentry
import XCTest

class SentryExperimentalOptionsTests: XCTestCase {

    // MARK: - Dictionary Population

    func testpopulateFromDict_whenOptionsAreNil_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.populateFrom(dict: nil)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testpopulateFromDict_whenOptionsAreEmpty_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.populateFrom(dict: [:])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testpopulateFromDict_whenDataCollectionIsEmpty_shouldSetDefaultDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.populateFrom(dict: ["dataCollection": [:]])

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
    }

    func testpopulateFromDict_whenDataCollectionHasWrongType_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.populateFrom(dict: ["dataCollection": "off"])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testpopulateFromDict_whenDataCollectionIsNSNull_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.populateFrom(dict: ["dataCollection": NSNull()])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testpopulateFromDict_whenDataCollectionIsPresent_shouldSetDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        let dictionary: [String: Any] = [
            "dataCollection": [
                "userInfo": false,
                "graphql": ["variables": false],
                "database": ["queryParams": false],
                "frameContextLines": 0
            ]
        ]

        // -- Act --
        options.populateFrom(dict: dictionary)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
        XCTAssertFalse(options.dataCollection.graphql.variables)
        XCTAssertFalse(options.dataCollection.database.queryParams)
        XCTAssertEqual(options.dataCollection.frameContextLines, 0)
    }
}
