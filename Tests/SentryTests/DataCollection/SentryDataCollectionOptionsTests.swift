@_spi(Private) @testable import Sentry
import XCTest

class SentryDataCollectionOptionsTests: XCTestCase {

    // MARK: - Default Init

    func testInit_withoutArguments_shouldHaveSpecDefaults() throws {
        // -- Act --
        let options = SentryDataCollection.Options()

        // -- Assert --
        XCTAssertTrue(options.userInfo)
        XCTAssertEqual(options.cookies, .denyList())
        XCTAssertEqual(options.httpHeaders.request, .denyList())
        XCTAssertEqual(options.httpHeaders.response, .denyList())
        XCTAssertEqual(options.httpBodies, .all)
        XCTAssertEqual(options.urlQueryParams, .denyList())
    }

    func testInit_withoutArguments_shouldExposeOnlySupportedCategories() throws {
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
    }

    // MARK: - Parameterized Init

    func testInit_withAllArguments_shouldSetAllProperties() throws {
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
    }

    func testDataCollectionObjC_whenAccessed_shouldWrapEntireDataCollection() throws {
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
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenUnsupportedCategoriesArePresent_shouldIgnoreThem() throws {
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
    }

    func testInitWithDictionary_whenUserInfoIsPresent_shouldSetUserInfo() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": false])

        // -- Assert --
        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenUserInfoHasWrongType_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": "false"])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenValuesMissing_shouldUseSpecDefaults() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.Options())
    }

    func testInitWithDictionary_whenCookiesIsPresent_shouldSetCookies() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": ["mode": "off"]])

        // -- Assert --
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
    }

    func testInitWithDictionary_whenCookiesHasWrongType_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": "off"])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenCookiesIsNSNull_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenHttpHeadersIsPresent_shouldSetHttpHeaders() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpHeaders": ["request": ["mode": "off"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders.request, .off)
        XCTAssertEqual(options.httpHeaders.response, SentryDataCollection.Options().httpHeaders.response)
    }

    func testInitWithDictionary_whenHttpHeadersHasWrongType_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": "off"])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpHeadersIsNSNull_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpBodies": ["outgoingRequest", "incomingResponse"]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
    }

    func testInitWithDictionary_whenHttpBodiesHasWrongType_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": "incomingRequest"])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsNSNull_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsEmptyArray_shouldDisableBodyCollection() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": []])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [])
    }

    func testInitWithDictionary_whenHttpBodiesContainsUnknownValues_shouldIgnoreUnknownValues() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": ["incomingRequest", "unknown", 1]])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.incomingRequest])
    }

    func testInitWithDictionary_whenUrlQueryParamsIsPresent_shouldSeturlQueryParams() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "urlQueryParams": ["mode": "allowList", "terms": ["page"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, .allowList(terms: ["page"]))
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenUrlQueryParamsHasWrongType_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["urlQueryParams": "off"])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
    }

    func testInitWithDictionary_whenUrlQueryParamsIsNSNull_shouldUseDefault() throws {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["urlQueryParams": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.urlQueryParams, SentryDataCollection.Options().urlQueryParams)
    }

    // MARK: - Equatable

    func testEquatable_defaultInstances_shouldBeEqual() throws {
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options()

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertTrue(isEqual)
    }

    func testEquatable_differentValues_shouldNotBeEqual() throws {
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
    }
}
