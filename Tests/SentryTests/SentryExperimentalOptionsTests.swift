@_spi(Private) @testable import Sentry
import XCTest

class SentryExperimentalOptionsTests: XCTestCase {

    // MARK: - validateOptions

    func testValidateOptions_whenOptionsAreNil_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.validateOptions(nil)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testValidateOptions_whenOptionsAreEmpty_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.validateOptions([:])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testValidateOptions_whenDataCollectionIsEmpty_shouldSetDefaultDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.validateOptions(["dataCollection": [:]])

        // -- Assert --
        XCTAssertEqual(options.dataCollection, SentryDataCollection.Options())
    }

    func testValidateOptions_whenDataCollectionHasWrongType_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.validateOptions(["dataCollection": "off"])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testValidateOptions_whenDataCollectionIsNSNull_shouldKeepExistingDataCollection() {
        // -- Arrange --
        let options = SentryExperimentalOptions()
        options.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        options.validateOptions(["dataCollection": NSNull()])

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
    }

    func testValidateOptions_whenDataCollectionIsPresent_shouldSetDataCollection() {
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
        options.validateOptions(dictionary)

        // -- Assert --
        XCTAssertFalse(options.dataCollection.userInfo)
        XCTAssertFalse(options.dataCollection.graphql.variables)
        XCTAssertFalse(options.dataCollection.database.queryParams)
        XCTAssertEqual(options.dataCollection.frameContextLines, 0)
    }
}
