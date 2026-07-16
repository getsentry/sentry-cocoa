@_spi(Private) @testable import Sentry
import XCTest

class SentryGraphQLCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions()

        // -- Assert --
        XCTAssertTrue(options.document)
        XCTAssertTrue(options.variables)
        #endif
    }

    func testInit_withArguments_shouldSetProperties() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(document: false, variables: true)

        // -- Assert --
        XCTAssertFalse(options.document)
        XCTAssertTrue(options.variables)
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenDocumentIsPresent_shouldSetDocument() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["document": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.document)
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
        #endif
    }

    func testInitWithDictionary_whenVariablesIsPresent_shouldSetVariables() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        XCTAssertFalse(options.variables)
        #endif
    }

    func testInitWithDictionary_whenVariablesIsMissing_shouldUseVariablesDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["document": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.document)
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
        #endif
    }

    func testInitWithDictionary_whenDocumentIsMissing_shouldUseDocumentDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        XCTAssertFalse(options.variables)
        #endif
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldUseDefaults() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.GraphQLCollectionOptions())
        #endif
    }

    func testInitWithDictionary_whenDocumentHasWrongType_shouldUseDocumentDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["document": "false"]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        #endif
    }

    func testInitWithDictionary_whenDocumentIsNSNull_shouldUseDocumentDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["document": NSNull()]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        #endif
    }

    func testInitWithDictionary_whenVariablesHasWrongType_shouldUseVariablesDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": "false"]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
        #endif
    }

    func testInitWithDictionary_whenVariablesIsNSNull_shouldUseVariablesDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": NSNull()]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.variables, SentryDataCollection.GraphQLCollectionOptions().variables)
        #endif
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

    func testInitWithDictionary_whenDocumentIsMissing_shouldUseDocumentDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["variables": false]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.document, SentryDataCollection.GraphQLCollectionOptions().document)
        XCTAssertFalse(options.variables)
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldUseDefaults() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.GraphQLCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.GraphQLCollectionOptions())
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
