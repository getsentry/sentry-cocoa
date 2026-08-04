@_spi(Private) @testable import Sentry
import XCTest

class SentryDataCollectionOptionsTests: XCTestCase {

    // MARK: - Default Init

    func testInit_withoutArguments_shouldHaveSpecDefaults() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options()

        // -- Assert --
        XCTAssertTrue(options.userInfo)
        XCTAssertEqual(options.cookies, .denyList())
        XCTAssertEqual(options.httpHeaders.request, .denyList())
        XCTAssertEqual(options.httpHeaders.response, .denyList())
        XCTAssertEqual(options.httpBodies, .all)
        XCTAssertEqual(options.urlQueryParams, .denyList())
        #endif
    }

    func testInit_withoutArguments_shouldExposeOnlySupportedCategories() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let propertyNames = Set(Mirror(reflecting: SentryDataCollection.Options()).children.compactMap(\.label))

        // -- Assert --
        XCTAssertEqual(propertyNames, [
            "cookies",
            "httpBodies",
            "httpHeaders",
            "urlQueryParams",
            "userInfo"
        ])
        #endif
    }

    // MARK: - Parameterized Init

    func testInit_withAllArguments_shouldSetAllProperties() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(
            userInfo: false,
            cookies: .off,
            httpHeaders: SentryDataCollection.HttpHeaderCollectionOptions(
                request: .denyList(terms: ["x-custom"]),
                response: .allowList(terms: ["content-type"])
            ),
            httpBodies: [.outgoingRequest, .incomingResponse],
            urlQueryParams: .allowList(terms: ["page"])
        )

        // -- Assert --
        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.httpHeaders.request, .denyList(terms: ["x-custom"]))
        XCTAssertEqual(options.httpHeaders.response, .allowList(terms: ["content-type"]))
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.urlQueryParams, .allowList(terms: ["page"]))
        #endif
    }

    func testDataCollectionObjC_whenAccessed_shouldWrapEntireDataCollection() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dataCollection = SentryDataCollection.Options(
            userInfo: false,
            cookies: .off,
            httpHeaders: .init(request: .allowList(terms: ["x-request"]), response: .off),
            httpBodies: [],
            urlQueryParams: .allowList(terms: ["page"])
        )
        let options = Options()
        options.dataCollection = dataCollection

        // -- Act --
        let objcOptions = options.dataCollectionObjC

        // -- Assert --
        XCTAssertEqual(objcOptions.wrapped, dataCollection)
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenUnsupportedCategoriesArePresent_shouldIgnoreThem() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "database": ["queryParams": false],
            "frameContextLines": 0,
            "genAI": ["inputs": false, "outputs": false],
            "graphQL": ["document": false, "variables": false],
            "graphql": ["document": false, "variables": false],
            "queues": false,
            "stackFrameVariables": false,
            "userInfo": false
        ])

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.Options(userInfo: false))
        #endif
    }

    func testInitWithDictionary_whenUserInfoIsPresent_shouldSetUserInfo() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": false])

        // -- Assert --
        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
        #endif
    }

    func testInitWithDictionary_whenUserInfoHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": "false"])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
        #endif
    }

    func testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
        #endif
    }

    func testInitWithDictionary_whenValuesMissing_shouldUseSpecDefaults() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.Options())
        #endif
    }

    func testInitWithDictionary_whenCookiesIsPresent_shouldSetCookies() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": ["mode": "off"]])

        // -- Assert --
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
        #endif
    }

    func testInitWithDictionary_whenCookiesHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": "off"])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
        #endif
    }

    func testInitWithDictionary_whenCookiesIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
        #endif
    }

    func testInitWithDictionary_whenHttpHeadersIsPresent_shouldSetHttpHeaders() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpHeaders": ["request": ["mode": "off"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders.request, .off)
        XCTAssertEqual(options.httpHeaders.response, SentryDataCollection.Options().httpHeaders.response)
        #endif
    }

    func testInitWithDictionary_whenHttpHeadersHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": "off"])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
        #endif
    }

    func testInitWithDictionary_whenHttpHeadersIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
        #endif
    }

    func testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpBodies": ["outgoingRequest", "incomingResponse"]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
        #endif
    }

    func testInitWithDictionary_whenHttpBodiesHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": "incomingRequest"])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
        #endif
    }

    func testInitWithDictionary_whenHttpBodiesIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
        #endif
    }

    func testInitWithDictionary_whenHttpBodiesIsEmptyArray_shouldDisableBodyCollection() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": []])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [])
        #endif
    }

    func testInitWithDictionary_whenHttpBodiesContainsUnknownValues_shouldIgnoreUnknownValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": ["incomingRequest", "unknown", 1]])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.incomingRequest])
        #endif
    }

    func testInitWithDictionary_whenUrlQueryParamsIsPresent_shouldSeturlQueryParams() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "urlQueryParams": ["mode": "allowList", "terms": ["page"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, .allowList(terms: ["page"]))
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
        #endif
    }

    func testInitWithDictionary_whenUrlQueryParamsHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["urlQueryParams": "off"])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
        #endif
    }

    func testInitWithDictionary_whenUrlQueryParamsIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["urlQueryParams": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
        #endif
    }

    // MARK: - Equatable

    func testEquatable_defaultInstances_shouldBeEqual() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options()

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertTrue(isEqual)
        #endif
    }

    func testEquatable_differentValues_shouldNotBeEqual() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
        #endif
    }
}
