@_spi(Private) @testable import Sentry
import XCTest

class SentryHttpHeaderCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions()

        // -- Assert --
        XCTAssertEqual(options.request, .denyList())
        XCTAssertEqual(options.response, .denyList())
        #endif
    }

    func testInit_withArguments_shouldSetBothDirections() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(
            request: .allowList(terms: ["authorization"]),
            response: .off
        )

        // -- Assert --
        XCTAssertEqual(options.request, .allowList(terms: ["authorization"]))
        XCTAssertEqual(options.response, .off)
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenRequestIsPresent_shouldSetRequest() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "request": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, .off)
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
        #endif
    }

    func testInitWithDictionary_whenResponseIsPresent_shouldSetResponse() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "response": ["mode": "allowList", "terms": ["content-type"]]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        XCTAssertEqual(options.response, .allowList(terms: ["content-type"]))
        #endif
    }

    func testInitWithDictionary_whenResponseIsMissing_shouldUseResponseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "request": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, .off)
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
        #endif
    }

    func testInitWithDictionary_whenRequestIsMissing_shouldUseRequestDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [
            "response": ["mode": "off"]
        ]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        XCTAssertEqual(options.response, .off)
        #endif
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldUseDefaults() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.HttpHeaderCollectionOptions())
        #endif
    }

    func testInitWithDictionary_whenRequestHasWrongType_shouldUseRequestDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["request": "off"]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        #endif
    }

    func testInitWithDictionary_whenRequestIsNSNull_shouldUseRequestDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["request": NSNull()]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.request, SentryDataCollection.HttpHeaderCollectionOptions().request)
        #endif
    }

    func testInitWithDictionary_whenResponseHasWrongType_shouldUseResponseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["response": "off"]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
        #endif
    }

    func testInitWithDictionary_whenResponseIsNSNull_shouldUseResponseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["response": NSNull()]

        // -- Act --
        let options = SentryDataCollection.HttpHeaderCollectionOptions(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(options.response, SentryDataCollection.HttpHeaderCollectionOptions().response)
        #endif
    }
}
