@_spi(Private) @testable import Sentry
import XCTest

class SentryDataCollectionOptionsTests: XCTestCase {

    // MARK: - Default Init

    func testInit_withoutArguments_shouldHaveSpecDefaults() {
        // -- Act --
        let options = SentryDataCollection.Options()

        // -- Assert --
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
        // -- Act --
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

        // -- Assert --
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
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": false])

        // -- Assert --
        XCTAssertFalse(options.userInfo)
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenUserInfoHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": "false"])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["userInfo": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenValuesMissing_shouldUseSpecDefaults() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [:])

        // -- Assert --
        XCTAssertEqual(options, SentryDataCollection.Options())
    }

    func testInitWithDictionary_whenCookiesIsPresent_shouldSetCookies() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": ["mode": "off"]])

        // -- Assert --
        XCTAssertEqual(options.cookies, .off)
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenCookiesHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": "off"])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenCookiesIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["cookies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenHttpHeadersIsPresent_shouldSetHttpHeaders() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpHeaders": ["request": ["mode": "off"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders.request, .off)
        XCTAssertEqual(options.httpHeaders.response, SentryDataCollection.Options().httpHeaders.response)
    }

    func testInitWithDictionary_whenHttpHeadersHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": "off"])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpHeadersIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpHeaders": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpHeaders, SentryDataCollection.Options().httpHeaders)
    }

    func testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "httpBodies": ["outgoingRequest", "incomingResponse"]
        ])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.outgoingRequest, .incomingResponse])
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenHttpBodiesHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": "incomingRequest"])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, SentryDataCollection.Options().httpBodies)
    }

    func testInitWithDictionary_whenHttpBodiesIsEmptyArray_shouldDisableBodyCollection() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": []])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [])
    }

    func testInitWithDictionary_whenHttpBodiesContainsUnknownValues_shouldIgnoreUnknownValues() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["httpBodies": ["incomingRequest", "unknown", 1]])

        // -- Assert --
        XCTAssertEqual(options.httpBodies, [.incomingRequest])
    }

    func testInitWithDictionary_whenQueryParamsIsPresent_shouldSetQueryParams() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: [
            "queryParams": ["mode": "allowList", "terms": ["page"]]
        ])

        // -- Assert --
        XCTAssertEqual(options.queryParams, .allowList(terms: ["page"]))
        XCTAssertEqual(options.cookies, SentryDataCollection.Options().cookies)
    }

    func testInitWithDictionary_whenQueryParamsHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["queryParams": "off"])

        // -- Assert --
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenQueryParamsIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["queryParams": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.queryParams, SentryDataCollection.Options().queryParams)
    }

    func testInitWithDictionary_whenGraphqlIsPresent_shouldSetGraphql() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": ["document": false]])

        // -- Assert --
        XCTAssertFalse(options.graphql.document)
        XCTAssertEqual(options.graphql.variables, SentryDataCollection.Options().graphql.variables)
    }

    func testInitWithDictionary_whenGraphqlHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": "off"])

        // -- Assert --
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenGraphqlIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["graphql": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenDatabaseIsPresent_shouldSetDatabase() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": ["queryParams": false]])

        // -- Assert --
        XCTAssertFalse(options.database.queryParams)
        XCTAssertEqual(options.graphql, SentryDataCollection.Options().graphql)
    }

    func testInitWithDictionary_whenDatabaseHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": "off"])

        // -- Assert --
        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
    }

    func testInitWithDictionary_whenDatabaseIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["database": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.database, SentryDataCollection.Options().database)
    }

    func testInitWithDictionary_whenStackFrameVariablesIsPresent_shouldSetStackFrameVariables() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": false])

        // -- Assert --
        XCTAssertFalse(options.stackFrameVariables)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenStackFrameVariablesHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": "false"])

        // -- Assert --
        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
    }

    func testInitWithDictionary_whenStackFrameVariablesIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["stackFrameVariables": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.stackFrameVariables, SentryDataCollection.Options().stackFrameVariables)
    }

    func testInitWithDictionary_whenFrameContextLinesIsPresent_shouldSetFrameContextLines() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": 0])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, 0)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenFrameContextLinesIsPositiveNumber_shouldSetFrameContextLines() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": 10])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, 10)
        XCTAssertEqual(options.userInfo, SentryDataCollection.Options().userInfo)
    }

    func testInitWithDictionary_whenFrameContextLinesIsNegative_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": -1])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
    }

    func testInitWithDictionary_whenFrameContextLinesHasWrongType_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": "0"])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNull_shouldUseDefault() {
        // -- Act --
        let options = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNull()])

        // -- Assert --
        XCTAssertEqual(options.frameContextLines, SentryDataCollection.Options().frameContextLines)
    }

    func testInitWithDictionary_whenFrameContextLinesIsBoolean_shouldUseBooleanFallback() {
        // -- Act --
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": true])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": false])

        // -- Assert --
        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
    }

    func testInitWithDictionary_whenFrameContextLinesIsNSNumberBoolean_shouldUseBooleanFallback() {
        // -- Act --
        let enabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: true)])
        let disabled = SentryDataCollection.Options(dictionary: ["frameContextLines": NSNumber(value: false)])

        // -- Assert --
        XCTAssertEqual(enabled.frameContextLines, SentryDataCollection.Options().frameContextLines)
        XCTAssertEqual(disabled.frameContextLines, 0)
    }

    // MARK: - Options Integration

    func testOptions_dataCollection_hasSpecDefaults() {
        // -- Act --
        let options = Options()

        // -- Assert --
        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptions_dataCollection_canBeSet() {
        // -- Arrange --
        let options = Options()

        // -- Act --
        options.experimental.dataCollection = SentryDataCollection.Options(userInfo: false)

        // -- Assert --
        XCTAssertFalse(options.experimental.dataCollection.userInfo)
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsPresent_shouldSetDataCollection() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": [
                    "userInfo": false
                ]
            ]
        ]

        // -- Act --
        let options = try SentryOptionsInternal.initWithDict(dictionary)

        // -- Assert --
        XCTAssertFalse(options.experimental.dataCollection.userInfo)
        XCTAssertEqual(options.experimental.dataCollection.cookies, SentryDataCollection.Options().cookies)
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsAbsent_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [:]
        ]

        // -- Act --
        let options = try SentryOptionsInternal.initWithDict(dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionHasWrongType_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": "off"
            ]
        ]

        // -- Act --
        let options = try SentryOptionsInternal.initWithDict(dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    func testOptionsWithDictionary_whenExperimentalDataCollectionIsNSNull_shouldUseDefault() throws {
        // -- Arrange --
        let dictionary: [String: Any] = [
            "dsn": "https://username:password@sentry.io/1",
            "experimental": [
                "dataCollection": NSNull()
            ]
        ]

        // -- Act --
        let options = try SentryOptionsInternal.initWithDict(dictionary)

        // -- Assert --
        XCTAssertEqual(options.experimental.dataCollection, SentryDataCollection.Options())
    }

    // MARK: - Equatable

    func testEquatable_defaultInstances_shouldBeEqual() {
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options()

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertTrue(isEqual)
    }

    func testEquatable_differentValues_shouldNotBeEqual() {
        // -- Arrange --
        let a = SentryDataCollection.Options()
        let b = SentryDataCollection.Options(userInfo: false)

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
    }
}
