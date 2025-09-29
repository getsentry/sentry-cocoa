@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// You have to start the test server before running this test. You can do this by calling
/// `make run-test-server` on your terminal.
/// Other tests validating the functionality of the SentryNetworkTrackerIntegration are located in SentryNetworkTrackerIntegrationTests.swift
/// This test is excluded from the SentryBase test plan because it requires the test server to be running. We have an extra test plan SentryTestServer,
/// so we can run this test in our CI isolated without having to have the test server running for all other tests.
class SentryNetworkTrackerIntegrationTestServerTests: XCTestCase {

    func testGetRequest_SpanCreatedAndBaggageHeaderAdded() throws {
        try ensureTestServerIsRunning()

        let testBaggageURL = try XCTUnwrap(URL(string: "http://localhost:8080/echo-baggage-header"))

        startSDK()

        let transaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as? SentryTracer)
        let expect = expectation(description: "Request completed")
        let session = URLSession(configuration: URLSessionConfiguration.default)

        let dataTask = session.dataTask(with: testBaggageURL) { (data, _, error) in
            self.assertNetworkError(error)
            let response = String(data: data ?? Data(), encoding: .utf8) ?? ""

            let expectedBaggageHeader = transaction.traceContext?.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
            XCTAssertEqual(expectedBaggageHeader, response)

            expect.fulfill()
        }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        let children = try XCTUnwrap(Dynamic(transaction).children as [Span]?)

        XCTAssertEqual(children.count, 1) //Span was created in task resume swizzle.
        let networkSpan = try XCTUnwrap(children.first)
        XCTAssertTrue(networkSpan.isFinished) //Span was finished in task setState swizzle.
        XCTAssertEqual("http.client", networkSpan.operation)
        XCTAssertEqual("GET \(testBaggageURL)", networkSpan.spanDescription)

        XCTAssertEqual("200", networkSpan.data["http.response.status_code"] as? String)
    }

    func testGetRequest_CompareSentryTraceHeader() throws {
        try ensureTestServerIsRunning()

        let testTraceURL = try XCTUnwrap(URL(string: "http://localhost:8080/echo-sentry-trace"))

        startSDK()

        let transaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as? SentryTracer)
        let expect = expectation(description: "Request completed")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var response: String?
        let dataTask = session.dataTask(with: testTraceURL) { (data, _, error) in
            self.assertNetworkError(error)
            response = String(data: data ?? Data(), encoding: .utf8) ?? ""
            expect.fulfill()
        }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        let children = Dynamic(transaction).children as [SentrySpan]?

        XCTAssertEqual(children?.count, 1) //Span was created in task resume swizzle.
        let networkSpan = try XCTUnwrap(children?.first)

        let expectedTraceHeader = networkSpan.toTraceHeader().value()
        XCTAssertEqual(expectedTraceHeader, response)
    }

    func testGetCaptureFailedRequestsEnabled() throws {
        try ensureTestServerIsRunning()

        let clientErrorTraceURL = try XCTUnwrap(URL(string: "http://localhost:8080/http-client-error"))

        let expect = expectation(description: "Request completed")
        expect.expectedFulfillmentCount = 2

        var sentryEvent: Event?

        startSDK {
            $0.enableCaptureFailedRequests = true
            $0.failedRequestStatusCodes = [ HttpStatusCodeRange(statusCode: 400) ]
            $0.beforeSend = { event in
                sentryEvent = event
                expect.fulfill()
                return event
            }
        }

        let session = URLSession(configuration: URLSessionConfiguration.default)

        let dataTask = session.dataTask(with: clientErrorTraceURL) { (_, _, error) in
            self.assertNetworkError(error)
            expect.fulfill()
        }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        XCTAssertNotNil(sentryEvent)
        XCTAssertNotNil(sentryEvent?.request)

        let sentryResponse = try XCTUnwrap(sentryEvent?.context?["response"], "Expected context.response, but was nil")
        let statusCode = try XCTUnwrap(sentryResponse["status_code"] as? NSNumber, "Expected context.response.status_code, but was nil")

        XCTAssertEqual(statusCode, 400)
    }

    private func assertNetworkError(_ error: Error?) {
        if error != nil {
            XCTFail("Failed to complete request : \(String(describing: error))")
        }
    }

    // We can't use a XCTTestExpectation here because we want to retry multiple times.
    // If a XCTestExpectation times out, the test would fail.
    // swiftlint:disable avoid_dispatch_groups_in_tests
    private func ensureTestServerIsRunning() throws {
        let testUrl = try XCTUnwrap(URL(string: "http://localhost:8080/"))

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let attempts = 20

        //swiftlint:disable:next for_where
        for attempt in 1..<attempts {
            let group = DispatchGroup()
            var isReady = false

            group.enter()
            let dataTask = session.dataTask(with: testUrl) { (_, response, error) in
                if error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    isReady = true
                }
                group.leave()
            }
            
            dataTask.resume()

            // We don't care about the result, we just want to wait up to 2 seconds for the request to complete.
            // If it doesn't work we retry.
            _ = group.wait(timeout: .now() + 2)

            if isReady {
                print("Test server is ready after \(attempt) attempt(s)")
                return
            }
            
            if attempt < 10 {
                print("Test server not ready, retrying in 1 second... (attempt \(attempt)/10)")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        XCTFail("Test server failed to become ready after \(attempts) attempts")
    }
    // swiftlint:enable avoid_dispatch_groups_in_tests

    private func startSDK(function: String = #function, _ configureOptions: ((Options) -> Void)? = nil) {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTestServerTests.\(function)")
        options.tracesSampleRate = 1.0

        configureOptions?(options)

        SentrySDK.start(options: options)
    }
}
