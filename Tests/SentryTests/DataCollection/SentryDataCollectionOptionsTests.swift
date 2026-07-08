@_spi(Private) @testable import Sentry
import XCTest

class SentryDataCollectionOptionsTests: XCTestCase {

    // MARK: - Default Init

    func testInit_withoutArguments_shouldHaveSpecDefaults() {
        let options = SentryDataCollection.Options()

        XCTAssertTrue(options.userInfo)
        XCTAssertEqual(options.cookies, .denyList())
        XCTAssertEqual(options.httpHeaders.request, .denyList())
        XCTAssertEqual(options.httpHeaders.response, .denyList())
        XCTAssertEqual(options.httpBodies, .all)
        XCTAssertEqual(options.queryParams, .denyList())
        XCTAssertTrue(options.graphql.document)
        XCTAssertTrue(options.graphql.variables)
        XCTAssertTrue(options.database.queryParams)
        XCTAssertTrue(options.stackFrameVariables)
        XCTAssertEqual(options.frameContextLines, 5)
    }

    // MARK: - Parameterized Init

    func testInit_withAllArguments_shouldSetAllProperties() {
        let options = SentryDataCollection.Options(
            userInfo: false,
            cookies: .off,
            httpHeaders: SentryDataCollection.HttpHeaderCollectionOptions(
                request: .denyList(terms: ["x-custom"]),
                response: .allowList(terms: ["content-type"])
            ),
            httpBodies: [.outgoingRequest, .incomingResponse],
            queryParams: .allowList(terms: ["page"]),
            graphql: SentryDataCollection.GraphQLCollectionOptions(document: false, variables: true),
            database: SentryDataCollection.DatabaseCollectionOptions(queryParams: false),
            stackFrameVariables: false,
            frameContextLines: 0
        )

        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.httpHeaders.request, .denyList(terms: ["x-custom"]))
        XCTAssertEqual(options.httpHeaders.response, .allowList(terms: ["content-type"]))
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.queryParams, .allowList(terms: ["page"]))
        XCTAssertFalse(options.graphql.document)
        XCTAssertTrue(options.graphql.variables)
        XCTAssertFalse(options.database.queryParams)
        XCTAssertFalse(options.stackFrameVariables)
        XCTAssertEqual(options.frameContextLines, 0)
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenUserInfoIsPresent_shouldSetUserInfo() {
        let options = SentryDataCollection.Options(dictionary: ["userInfo": false])

        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenUserInfoHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["userInfo": "false"])

        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["userInfo": NSNull()])

        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenValuesMissing_shouldUseSpecDefaults() {
        let options = SentryDataCollection.Options(dictionary: [:])

        XCTAssertEqual(options, SentryDataCollection.Options())
    }

    func testInitWithDictionary_whenCookiesIsPresent_shouldSetCookies() {
        let options = SentryDataCollection.Options(dictionary: ["cookies": ["mode": "off"]])

        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenCookiesHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["cookies": "off"])

        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenCookiesIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["cookies": NSNull()])

        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenHttpHeadersIsPresent_shouldSetHttpHeaders() {
        let options = SentryDataCollection.Options(dictionary: [
            "httpHeaders": ["request": ["mode": "off"]]
        ])

        XCTAssertEqual(options.httpHeaders.request, .off)
        XCTAssertEqual(options.httpHeaders.response, SentryDataCollection.Options().httpHeaders.response)
    }

    func testInitWithDictionary_whenHttpHeadersHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": "off"])

        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpHeadersIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": NSNull()])

        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies() {
        let options = SentryDataCollection.Options(dictionary: [
            "httpBodies": ["outgoingRequest", "incomingResponse"]
        ])

        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenHttpBodiesHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": "incomingRequest"])

        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": NSNull()])

        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsEmptyArray_shouldDisableBodyCollection() {
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": []])

        XCTAssertEqual(options.httpBodies, [])
    }

    func testInitWithDictionary_whenHttpBodiesContainsUnknownValues_shouldIgnoreUnknownValues() {
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": ["incomingRequest", "unknown", 1]])

        XCTAssertEqual(options.httpBodies, [.incomingRequest])
    }

    func testInitWithDictionary_whenQueryParamsIsPresent_shouldSetQueryParams() {
        let options = SentryDataCollection.Options(dictionary: [
            "queryParams": ["mode": "allowList", "terms": ["page"]]
        ])

        XCTAssertEqual(options.queryParams, .allowList(terms: ["page"]))
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenQueryParamsHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["queryParams": "off"])

        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenQueryParamsIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["queryParams": NSNull()])

        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenGraphqlIsPresent_shouldSetGraphql() {
        let options = SentryDataCollection.Options(dictionary: ["graphql": ["document": false]])

        XCTAssertFalse(options.graphql.document)
        XCTAssertEqual(options.graphql.variables, SentryDataCollection.Options().graphql.variables)
    }

    func testInitWithDictionary_whenGraphqlHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["graphql": "off"])

        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenGraphqlIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["graphql": NSNull()])

        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenDatabaseIsPresent_shouldSetDatabase() {
        let options = SentryDataCollection.Options(dictionary: ["database": ["queryParams": false]])

        XCTAssertFalse(options.database.queryParams)
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenDatabaseHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["database": "off"])

        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
    }

    func testInitWithDictionary_whenDatabaseIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["database": NSNull()])

        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
    }

    func testInitWithDictionary_whenStackFrameVariablesIsPresent_shouldSetStackFrameVariables() {
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": false])

        XCTAssertFalse(options.stackFrameVariables)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenStackFrameVariablesHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": "false"])

        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
    }

    func testInitWithDictionary_whenStackFrameVariablesIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": NSNull()])

        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
    }

    func testInitWithDictionary_whenFrameContextLinesIsPresent_shouldSetFrameContextLines() {
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": 0])

        XCTAssertEqual(options.frameContextLines, 0)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenFrameContextLinesHasWrongType_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": "0"])

        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNull_shouldUseDefault() {
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNull()])

        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
    }

    func testInitWithDictionary_whenFrameContextLinesIsBoolean_shouldUseBooleanFallback() {
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": true])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": false])

        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNumberBoolean_shouldUseBooleanFallback() {
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: true)])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: false)])

        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
    }

    // MARK: - Options Integration

    func testOptions_dataCollection_hasSpecDefaults() {
        let options = Options()

        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptions_dataCollection_canBeSet() {
        let options = Options()

        options.experimental.dataCollection = SentryDataCollection.Options(userInfo: false)

        XCTAssertFalse(options.experimental.dataCollection.userInfo)
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsPresent_shouldSetDataCollection() throws {
        let options = try SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": [
                    "userInfo": false
                ]
            ]
        ])

        XCTAssertFalse(options.experimental.dataCollection.userInfo)
        XCTAssertEqual(options.experimental.dataCollection.cookies, SentryDataCollection.Options().cookies)
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsAbsent_shouldUseDefault() throws {
        let options = try SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [:]
        ])

        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionHasWrongType_shouldUseDefault() throws {
        let options = try SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": "off"
            ]
        ])

        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsNSNull_shouldUseDefault() throws {
        let options = try SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": NSNull()
            ]
        ])

        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    // MARK: - Equatable

    func testEquatable_defaultInstances_shouldBeEqual() {
        XCTAssertEqual(SentryDataCollection.Options(), SentryDataCollection.Options())
    }

    func testEquatable_differentValues_shouldNotBeEqual() {
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options(userInfo: false)
        XCTAssertNotEqual(a, b)
    }
}
