@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpHeaderCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToDenyList() {
        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions()

        // -- Assert --
        XCTAssertEqual(options.request, .denyList())
        XCTAssertEqual(options.response, .denyList())
    }

    func testInit_withArguments_shouldSetBothDirections() {
        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(
            request: .allowList(terms: ["authorization"]),
            response: .off
        )

        // -- Assert --
        XCTAssertEqual(options.request, .allowList(terms: ["authorization"]))
        XCTAssertEqual(options.response, .off)
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenRequestIsPresent_shouldSetRequest() {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "request": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, .off)
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
    }

    func testInitWithDictionary_whenResponseIsPresent_shouldSetResponse() {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "response": ["mode": "allowList", "terms": ["content-type"]]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        XCTAssertEqual(options.response, .allowList(terms: ["content-type"]))
    }

    func testInitWithDictionary_whenResponseIsMissing_shouldUseResponseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "request": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, .off)
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
    }

    func testInitWithDictionary_whenRequestIsMissing_shouldUseRequestDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "response": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        XCTAssertEqual(options.response, .off)
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldUseDefaults() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.HttpHeaderCollectionOptions())
    }

    func testInitWithDictionary_whenRequestHasWrongType_shouldUseRequestDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["request": "off"]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
    }

    func testInitWithDictionary_whenRequestIsNSNull_shouldUseRequestDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["request": NSNull()]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
    }

    func testInitWithDictionary_whenResponseHasWrongType_shouldUseResponseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["response": "off"]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
    }

    func testInitWithDictionary_whenResponseIsNSNull_shouldUseResponseDefault() {
        // -- Arrange --
        let dictionary: [String: Any] = ["response": NSNull()]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
    }
}
