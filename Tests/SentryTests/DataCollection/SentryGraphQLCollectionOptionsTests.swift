@_spi(Private) @testable import Sentry
import XCTest

class SentryGraphQLCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() {
        let options = SentryDataCollection.GraphQLCollectionOptions()
        XCTAssertTrue(options.document)
        XCTAssertTrue(options.variables)
    }

    func testInit_withArguments_shouldSetProperties() {
        let options = SentryDataCollection.GraphQLCollectionOptions(document: false, variables: true)
        XCTAssertFalse(options.document)
        XCTAssertTrue(options.variables)
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenDocumentIsPresent_shouldSetDocument() {
        // -- Arrange --
        let dictionary: [String: Any] = ["document": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.document)
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
    }

    func testInitWithDictionary_whenVariablesIsPresent_shouldSetVariables() {
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        XCTAssertFalse(options.variables)
    }

    func testInitWithDictionary_whenVariablesIsMissing_shouldUseVariablesDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["document": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.document)
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
    }

    func testInitWithDictionary_whenDocumentHasWrongType_shouldUseDocumentDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["document": "false"]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
    }

    func testInitWithDictionary_whenDocumentIsNSNull_shouldUseDocumentDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["document": NSNull()]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
    }

    func testInitWithDictionary_whenVariablesHasWrongType_shouldUseVariablesDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": "false"]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
    }

    func testInitWithDictionary_whenVariablesIsNSNull_shouldUseVariablesDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": NSNull()]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
    }
}
