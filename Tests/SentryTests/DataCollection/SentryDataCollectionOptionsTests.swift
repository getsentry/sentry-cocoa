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
        XCTAssertTrue(options.graphql.document)
        XCTAssertTrue(options.graphql.variables)
        XCTAssertTrue(options.database.queryParams)
        XCTAssertTrue(options.stackFrameVariables)
        XCTAssertEqual(options.frameContextLines, 5)
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
            urlQueryParams: .allowList(terms: ["page"]),
            graphql: SentryDataCollection.GraphQLCollectionOptions(document: false, variables: true),
            database: SentryDataCollection.DatabaseCollectionOptions(queryParams: false),
            stackFrameVariables: false,
            frameContextLines: 0
        )

        // -- Assert --
        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.httpHeaders.request, .denyList(terms: ["x-custom"]))
        XCTAssertEqual(options.httpHeaders.response, .allowList(terms: ["content-type"]))
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.urlQueryParams, .allowList(terms: ["page"]))
        XCTAssertFalse(options.graphql.document)
        XCTAssertTrue(options.graphql.variables)
        XCTAssertFalse(options.database.queryParams)
        XCTAssertFalse(options.stackFrameVariables)
        XCTAssertEqual(options.frameContextLines, 0)
        #endif
    }

    // MARK: - Dictionary Init

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

    func testInitWithDictionary_whenGraphqlIsPresent_shouldSetGraphql() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": ["document": false]])

        // -- Assert --
        XCTAssertFalse(options.graphql.document)
        XCTAssertEqual(options.graphql.variables, SentryDataCollection.Options().graphql.variables)
        #endif
    }

    func testInitWithDictionary_whenGraphqlHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": "off"])

        // -- Assert --
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
        #endif
    }

    func testInitWithDictionary_whenGraphqlIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
        #endif
    }

    func testInitWithDictionary_whenDatabaseIsPresent_shouldSetDatabase() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": ["queryParams": false]])

        // -- Assert --
        XCTAssertFalse(options.database.queryParams)
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
        #endif
    }

    func testInitWithDictionary_whenDatabaseHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": "off"])

        // -- Assert --
        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
        #endif
    }

    func testInitWithDictionary_whenDatabaseIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
        #endif
    }

    func testInitWithDictionary_whenStackFrameVariablesIsPresent_shouldSetStackFrameVariables() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": false])

        // -- Assert --
        XCTAssertFalse(options.stackFrameVariables)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
        #endif
    }

    func testInitWithDictionary_whenStackFrameVariablesHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": "false"])

        // -- Assert --
        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
        #endif
    }

    func testInitWithDictionary_whenStackFrameVariablesIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsPresent_shouldSetFrameContextLines() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": 0])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, 0)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsPositiveNumber_shouldSetFrameContextLines() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": 10])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, 10)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNumberOne_shouldSetFrameContextLines() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: 1)])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, 1)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsNegative_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": -1])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesHasWrongType_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": "0"])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNull_shouldUseDefault() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsBoolean_shouldUseBooleanFallback() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": true])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": false])

        // -- Assert --
        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
        #endif
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNumberBoolean_shouldUseBooleanFallback() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: true)])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: false)])

        // -- Assert --
        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
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
