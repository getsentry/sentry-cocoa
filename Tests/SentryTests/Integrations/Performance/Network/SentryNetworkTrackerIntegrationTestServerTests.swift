@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

/// You have to start the test server before running this test. You can do this by calling
/// `make run-test-server` on your terminal.
/// Other tests validating the functionality of the SentryNetworkTrackerIntegration are located in SentryNetworkTrackerIntegrationTests.swift
/// This test is excluded from the SentryBase test plan because it requires the test server to be running. We have an extra test plan SentryTestServer,
/// so we can run this test in our CI isolated without having to have the test server running for all other tests.
class SentryNetworkTrackerIntegrationTestServerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testGetRequest_SpanCreatedAndBaggageHeaderAdded() throws {
        try ensureTestServerIsRunning()

        let testBaggageURL = try XCTUnwrap(URL(string: "http://localhost:8081/echo-baggage-header"))

        startSDK()

        let transaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as? SentryTracer)

        let expect = expectation(description: "Request completed")
        // Cancelling the task in defer can trigger the completion handler again.
        expect.assertForOverFulfill = false

        let session = URLSession(configuration: URLSessionConfiguration.default)

        let dataTask = session.dataTask(with: testBaggageURL) { (data, _, error) in
            self.assertNetworkError(error)
            let response = String(data: data ?? Data(), encoding: .utf8) ?? ""

            let expectedBaggageHeader = transaction.traceContext?.toBaggage().toHTTPHeader(withOriginalBaggage: nil)
            XCTAssertEqual(expectedBaggageHeader, response)

            expect.fulfill()
        }

        defer { dataTask.cancel() }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        let children = try XCTUnwrap(Dynamic(transaction).children as [Span]?)

        XCTAssertEqual(children.count, 1) //Span was created in task resume swizzle.
        let networkSpan = try XCTUnwrap(children.first)
        XCTAssertTrue(networkSpan.isFinished) //Span was finished in task setState swizzle.
        XCTAssertEqual("http.client", networkSpan.operation)
        XCTAssertEqual("GET \(testBaggageURL)", networkSpan.spanDescription)

        XCTAssertEqual(NSNumber(value: 200), networkSpan.data["http.response.status_code"] as? NSNumber)
    }

    func testGetRequest_CompareSentryTraceHeader() throws {
        try ensureTestServerIsRunning()

        let testTraceURL = try XCTUnwrap(URL(string: "http://localhost:8081/echo-sentry-trace"))

        startSDK()

        let transaction = try XCTUnwrap(SentrySDK.startTransaction(name: "Test Transaction", operation: "TEST", bindToScope: true) as? SentryTracer)

        let expect = expectation(description: "Request completed")
        // Cancelling the task in defer can trigger the completion handler again.
        expect.assertForOverFulfill = false

        let session = URLSession(configuration: URLSessionConfiguration.default)
        var response: String?
        let dataTask = session.dataTask(with: testTraceURL) { (data, _, error) in
            self.assertNetworkError(error)
            response = String(data: data ?? Data(), encoding: .utf8) ?? ""
            expect.fulfill()
        }

        defer { dataTask.cancel() }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        let children = Dynamic(transaction).children as [SentrySpanInternal]?

        XCTAssertEqual(children?.count, 1) //Span was created in task resume swizzle.
        let networkSpan = try XCTUnwrap(children?.first)

        let expectedTraceHeader = networkSpan.toTraceHeader().value()
        XCTAssertEqual(expectedTraceHeader, response)
    }

    func testDownloadRequest_CompareSentryTraceHeader() throws {
        // -- Arrange --
        try ensureTestServerIsRunning()
        let testTraceURL = try XCTUnwrap(URL(string: "http://localhost:8081/echo-sentry-trace"))
        startSDK()
        let transaction = try XCTUnwrap(
            SentrySDK.startTransaction(
                name: "Test Transaction",
                operation: "TEST",
                bindToScope: true
            ) as? SentryTracer
        )
        let requestCompleted = expectation(description: "Download request completed")
        var response: String?
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.downloadTask(with: testTraceURL) { location, _, error in
            self.assertNetworkError(error)
            defer { requestCompleted.fulfill() }

            guard let location else {
                return XCTFail("Expected download location")
            }

            do {
                response = String(data: try Data(contentsOf: location), encoding: .utf8)
            } catch {
                XCTFail("Failed to read download response: \(error)")
            }
        }
        defer { task.cancel() }

        // -- Act --
        task.resume()
        wait(for: [requestCompleted], timeout: 10)

        // -- Assert --
        let children = Dynamic(transaction).children as [SentrySpanInternal]?
        let networkSpan = try XCTUnwrap(children?.first)
        XCTAssertEqual(networkSpan.toTraceHeader().value(), response)
    }

    func testUploadRequest_CompareSentryTraceHeader() throws {
        // -- Arrange --
        try ensureTestServerIsRunning()
        let testTraceURL = try XCTUnwrap(URL(string: "http://localhost:8081/echo-sentry-trace"))
        startSDK()
        let transaction = try XCTUnwrap(
            SentrySDK.startTransaction(
                name: "Test Transaction",
                operation: "TEST",
                bindToScope: true
            ) as? SentryTracer
        )
        let requestCompleted = expectation(description: "Upload request completed")
        var response: String?
        var request = URLRequest(url: testTraceURL)
        request.httpMethod = "POST"
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.uploadTask(with: request, from: Data("test".utf8)) { data, _, error in
            self.assertNetworkError(error)
            response = String(data: data ?? Data(), encoding: .utf8)
            requestCompleted.fulfill()
        }
        defer { task.cancel() }

        // -- Act --
        task.resume()
        wait(for: [requestCompleted], timeout: 10)

        // -- Assert --
        let children = Dynamic(transaction).children as [SentrySpanInternal]?
        let networkSpan = try XCTUnwrap(children?.first)
        XCTAssertEqual(networkSpan.toTraceHeader().value(), response)
    }

    func testGetCaptureFailedRequestsEnabled() throws {
        try ensureTestServerIsRunning()

        let clientErrorTraceURL = try XCTUnwrap(URL(string: "http://localhost:8081/http-client-error"))

        let expect = expectation(description: "Request completed")
        expect.expectedFulfillmentCount = 2
        // Cancelling the task in defer can trigger the completion handler again.
        expect.assertForOverFulfill = false

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

        defer { dataTask.cancel() }

        dataTask.resume()
        wait(for: [expect], timeout: 10)

        XCTAssertNotNil(sentryEvent)
        XCTAssertNotNil(sentryEvent?.request)

        let sentryResponse = try XCTUnwrap(sentryEvent?.context?["response"], "Expected context.response, but was nil")
        let statusCode = try XCTUnwrap(sentryResponse["status_code"] as? NSNumber, "Expected context.response.status_code, but was nil")

        XCTAssertEqual(statusCode, 400)
    }

    func testSuccessfulRequest_whenTransactionFinishes_shouldMatchEnvelopeSnapshot() throws {
        // -- Arrange --
        try ensureTestServerIsRunning()
        let url = try XCTUnwrap(URL(string: "http://localhost:8081/echo-sentry-trace"))
        let requestCompleted = expectationAllowingOverFulfill(description: "Request completed")
        let envelopeCaptured = expectationAllowingOverFulfill(description: "Envelope captured")
        let transport = startSDK(
            envelopeCaptured: envelopeCaptured,
            expectedEnvelopeItemType: SentryEnvelopeItemTypes.transaction
        ) {
            self.configureEnvelopeSnapshotOptions($0)
            $0.enableNetworkBreadcrumbs = false
        }
        let transaction = try XCTUnwrap(SentrySDK.startTransaction(
            name: "Network Envelope Snapshot",
            operation: "test.network",
            bindToScope: true
        ) as? SentryTracer)
        let dataTask = URLSession.shared.dataTask(with: url) { _, _, error in
            self.assertNetworkError(error)
            requestCompleted.fulfill()
        }
        defer { dataTask.cancel() }

        // -- Act --
        dataTask.resume()
        wait(for: [requestCompleted], timeout: 10)
        transaction.finish()
        wait(for: [envelopeCaptured], timeout: 10)

        // -- Assert --
        XCTAssertEqual(transport.sentEnvelopes.count, 1)
        let envelope = try XCTUnwrap(transport.sentEnvelopes.first)
        try NetworkEnvelopeSnapshot.assertMatches(
            envelope: envelope,
            resource: "successful-request-transaction",
            testCase: self
        )
    }

    func testFailedRequest_whenCaptureEnabled_shouldMatchEnvelopeSnapshot() throws {
        // -- Arrange --
        try ensureTestServerIsRunning()
        let url = try XCTUnwrap(URL(string: "http://localhost:8081/http-client-error"))
        let requestCompleted = expectationAllowingOverFulfill(description: "Request completed")
        let envelopeCaptured = expectationAllowingOverFulfill(description: "Envelope captured")
        let transport = startSDK(
            envelopeCaptured: envelopeCaptured,
            expectedEnvelopeItemType: SentryEnvelopeItemTypes.event
        ) {
            self.configureEnvelopeSnapshotOptions($0)
            $0.enableCaptureFailedRequests = true
            $0.failedRequestStatusCodes = [HttpStatusCodeRange(statusCode: 400)]
        }
        let dataTask = URLSession.shared.dataTask(with: url) { _, _, error in
            self.assertNetworkError(error)
            requestCompleted.fulfill()
        }
        defer { dataTask.cancel() }

        // -- Act --
        dataTask.resume()
        wait(for: [requestCompleted, envelopeCaptured], timeout: 10)

        // -- Assert --
        XCTAssertEqual(transport.sentEnvelopes.count, 1)
        let envelope = try XCTUnwrap(transport.sentEnvelopes.first)
        try NetworkEnvelopeSnapshot.assertMatches(
            envelope: envelope,
            resource: "failed-request-event",
            testCase: self
        )
    }

    private func assertNetworkError(_ error: Error?) {
        if error != nil {
            XCTFail("Failed to complete request : \(String(describing: error))")
        }
    }

    private func expectationAllowingOverFulfill(description: String) -> XCTestExpectation {
        let expectation = expectation(description: description)
        expectation.assertForOverFulfill = false
        return expectation
    }

    // We can't use a XCTTestExpectation here because we want to retry multiple times.
    // If a XCTestExpectation times out, the test would fail.
    // swiftlint:disable avoid_dispatch_groups_in_tests
    private func ensureTestServerIsRunning() throws {
        let testUrl = try XCTUnwrap(URL(string: "http://localhost:8081/"))

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let attempts = 20

        // swiftlint:disable:next for_where
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

            defer { dataTask.cancel() }

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

    private func configureEnvelopeSnapshotOptions(_ options: Options) {
        options.enableAutoSessionTracking = false
        options.enableAutoBreadcrumbTracking = false
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        options.enableUIViewControllerTracing = false
        options.enableUserInteractionTracing = false
#endif
        options.enableFileIOTracing = false
        options.enableDataSwizzling = false
        options.enableCoreDataTracing = false
        options.releaseName = "io.sentry.network-envelope-snapshot@1.0.0+1"
        options.environment = "test"
    }

    @discardableResult
    private func startSDK(
        function: String = #function,
        envelopeCaptured: XCTestExpectation? = nil,
        expectedEnvelopeItemType: String? = nil,
        _ configureOptions: ((Options) -> Void)? = nil
    ) -> EnvelopeCapturingTransport {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryNetworkTrackerIntegrationTestServerTests.\(function)")
        options.tracesSampleRate = 1.0

        configureOptions?(options)

        SentrySDK.start(options: options)

        let transport = EnvelopeCapturingTransport(
            expectation: envelopeCaptured,
            expectedEnvelopeItemType: expectedEnvelopeItemType
        )
        let client = SentrySDKInternal.currentHub().client()
        Dynamic(client).transportAdapter = SentryTransportAdapter(transports: [transport], options: options)
        return transport
    }

    private final class EnvelopeCapturingTransport: NSObject, Transport {
        let sentEnvelopes = Invocations<SentryEnvelope>()
        private let expectation: XCTestExpectation?
        private let expectedEnvelopeItemType: String?

        init(expectation: XCTestExpectation?, expectedEnvelopeItemType: String?) {
            self.expectation = expectation
            self.expectedEnvelopeItemType = expectedEnvelopeItemType
        }

        func send(envelope: SentryEnvelope) {
            if let expectedEnvelopeItemType,
               !envelope.items.contains(where: { $0.header.type == expectedEnvelopeItemType }) {
                return
            }
            sentEnvelopes.record(envelope)
            expectation?.fulfill()
        }

        func store(_ envelope: SentryEnvelope) {}

        func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {}

        func recordLostEvent(
            _ category: SentryDataCategory,
            reason: SentryDiscardReason,
            quantity: UInt
        ) {}

        func flush(_ timeout: TimeInterval) -> SentryFlushResult {
            .success
        }

        func setStartFlushCallback(_ callback: @escaping () -> Void) {}
    }
}
