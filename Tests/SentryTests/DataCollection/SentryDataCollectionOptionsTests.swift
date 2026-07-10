@testable import Sentry
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
