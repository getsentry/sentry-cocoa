#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// Integration tests that verify the completion-handler swizzling for replay's
/// network detail capture actually works end-to-end.
///
/// Unlike the unit tests in SentryNetworkTrackerTests (which call tracker
/// methods directly), these tests start the SDK, make real HTTP requests,
/// and assert that the swizzled completion handler fires and populates
/// network details on the resulting breadcrumb.
///
/// Uses postman-echo.com so no local test server is required.
class SentryNetworkDetailSwizzlingTests: XCTestCase {

    private let echoURL = URL(string: "https://postman-echo.com/get")!

    override func setUp() {
        super.setUp()

        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryNetworkDetailSwizzlingTests")
        options.tracesSampleRate = 1.0
        options.enableNetworkBreadcrumbs = true
        options.sessionReplay.networkDetailAllowUrls = ["postman-echo.com"]
        options.sessionReplay.networkCaptureBodies = true
        SentrySDK.start(options: options)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    // MARK: - Tests

    /// Verifies the swizzle of `-[NSURLSession dataTaskWithRequest:completionHandler:]`
    /// captures response details into the breadcrumb.
    func testDataTaskWithRequest_completionHandler_capturesNetworkDetails() throws {
        let transaction = SentrySDK.startTransaction(
            name: "Test", operation: "test", bindToScope: true
        )

        let expect = expectation(description: "Request completed")
        expect.assertForOverFulfill = false

        let session = URLSession(configuration: .default)
        let request = URLRequest(url: echoURL)

        var receivedData: Data?
        var receivedResponse: URLResponse?
        var receivedError: Error?

        let task = session.dataTask(with: request) { data, response, error in
            receivedData = data
            receivedResponse = response
            receivedError = error
            expect.fulfill()
        }
        defer { task.cancel() }

        task.resume()
        wait(for: [expect], timeout: 5)

        transaction.finish()

        // Original completion handler received valid data
        XCTAssertNil(receivedError, "Request should succeed")
        XCTAssertNotNil(receivedData, "Should receive response data")
        let httpResponse = try XCTUnwrap(receivedResponse as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)

        // Network details were captured via the swizzled completion handler
        let breadcrumb = try lastHTTPBreadcrumb(for: echoURL)
        let details = try XCTUnwrap(
            breadcrumb.data?[SentryReplayNetworkDetails.replayNetworkDetailsKey] as? SentryReplayNetworkDetails,
            "Swizzled completion handler should have populated network details on the breadcrumb"
        )
        let serialized = details.serialize()
        XCTAssertEqual(serialized["statusCode"] as? Int, 200)
        XCTAssertNotNil(serialized["response"], "Response details should be captured")
    }

    /// Verifies the swizzle of `-[NSURLSession dataTaskWithURL:completionHandler:]`
    /// captures response details into the breadcrumb.
    func testDataTaskWithURL_completionHandler_capturesNetworkDetails() throws {
        let transaction = SentrySDK.startTransaction(
            name: "Test", operation: "test", bindToScope: true
        )

        let expect = expectation(description: "Request completed")
        expect.assertForOverFulfill = false

        let session = URLSession(configuration: .default)

        var receivedData: Data?
        var receivedResponse: URLResponse?
        var receivedError: Error?

        let task = session.dataTask(with: echoURL) { data, response, error in
            receivedData = data
            receivedResponse = response
            receivedError = error
            expect.fulfill()
        }
        defer { task.cancel() }

        task.resume()
        wait(for: [expect], timeout: 5)

        transaction.finish()

        // Original completion handler received valid data
        XCTAssertNil(receivedError, "Request should succeed")
        XCTAssertNotNil(receivedData, "Should receive response data")
        let httpResponse = try XCTUnwrap(receivedResponse as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)

        // Network details were captured via the swizzled completion handler
        let breadcrumb = try lastHTTPBreadcrumb(for: echoURL)
        let details = try XCTUnwrap(
            breadcrumb.data?[SentryReplayNetworkDetails.replayNetworkDetailsKey] as? SentryReplayNetworkDetails,
            "Swizzled completion handler should have populated network details on the breadcrumb"
        )
        let serialized = details.serialize()
        XCTAssertEqual(serialized["statusCode"] as? Int, 200)
        XCTAssertNotNil(serialized["response"], "Response details should be captured")
    }

    // MARK: - Helpers

    /// Finds the most recent HTTP breadcrumb whose URL matches the given URL.
    private func lastHTTPBreadcrumb(for url: URL) throws -> Breadcrumb {
        let scope = SentrySDKInternal.currentHub().scope
        let breadcrumbs = try XCTUnwrap(
            Dynamic(scope).breadcrumbArray as [Breadcrumb]?,
            "Scope should contain breadcrumbs"
        )
        let matching = breadcrumbs.filter {
            $0.category == "http" && ($0.data?["url"] as? String)?.contains(url.host ?? "") == true
        }
        return try XCTUnwrap(matching.last, "Should find an HTTP breadcrumb for \(url)")
    }
}

#endif // os(iOS) || os(tvOS)
