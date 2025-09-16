@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/// You have to start the test server before running this test. You can do this by calling
/// `make run-test-server` on your terminal.
/// Other tests validating the functionality of the SentryNetworkTrackerIntegration are located in SentryNetworkTrackerIntegrationTests.swift
class SentryNetworkTrackerIntegrationTestServerTests: XCTestCase {

    func testGetRequest_SpanCreatedAndBaggageHeaderAdded() throws {
        let testBaggageURL = try XCTUnwrap(URL(string: "http://localhost:8080/echo-baggage-header"))

        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTestServerTests")
        options.tracesSampleRate = 1.0

        SentrySDK.start(options: options)

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
        wait(for: [expect], timeout: 5)

        let children = try XCTUnwrap(Dynamic(transaction).children as [Span]?)

        XCTAssertEqual(children.count, 1) //Span was created in task resume swizzle.
        let networkSpan = try XCTUnwrap(children.first)
        XCTAssertTrue(networkSpan.isFinished) //Span was finished in task setState swizzle.
        XCTAssertEqual("http.client", networkSpan.operation)
        XCTAssertEqual("GET \(testBaggageURL)", networkSpan.spanDescription)

        XCTAssertEqual("200", networkSpan.data["http.response.status_code"] as? String)
    }

    private func assertNetworkError(_ error: Error?) {
        if error != nil {
            XCTFail("Failed to complete request : \(String(describing: error))")
        }
    }
}
