@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHttpTransportFlushIntegrationTests: XCTestCase {

    private let flushTimeout: TimeInterval = 5.0

    func testFlush_WhenNoEnvelopes_BlocksAndFinishes() throws {

        let (sut, _, _, _) = try getSut()

        var blockingDurationSum: TimeInterval = 0.0
        let flushInvocations = 100

        for _ in  0..<flushInvocations {
            let beforeFlush = SentryDefaultCurrentDateProvider.getAbsoluteTime()
            XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")
            let blockingDuration = getDurationNs(beforeFlush, SentryDefaultCurrentDateProvider.getAbsoluteTime()).toTimeInterval()

            blockingDurationSum += blockingDuration
        }

        let blockingDurationAverage = blockingDurationSum / Double(flushInvocations)
        XCTAssertLessThan(blockingDurationAverage, 0.1)
    }

    func testFlush_WhenNoInternet_BlocksAndFinishes() throws {
        let (sut, requestManager, _, dispatchQueueWrapper) = try getSut()

        requestManager.returnResponse(response: nil)

        sut.send(envelope: SentryEnvelope(event: Event()))
        sut.send(envelope: SentryEnvelope(event: Event()))
        // Wait until the dispath queue drains to confirm the envelope is stored
        waitForEnvelopeToBeStored(dispatchQueueWrapper)

        var blockingDurationSum: TimeInterval = 0.0
        let flushInvocations = 100

        for _ in  0..<flushInvocations {
            let beforeFlush = SentryDefaultCurrentDateProvider.getAbsoluteTime()
            XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")
            let blockingDuration = getDurationNs(beforeFlush, SentryDefaultCurrentDateProvider.getAbsoluteTime()).toTimeInterval()

            blockingDurationSum += blockingDuration
        }

        let blockingDurationAverage = blockingDurationSum / Double(flushInvocations)
        XCTAssertLessThan(blockingDurationAverage, 0.1)
    }

    func testFlush_CallingFlushDirectlyAfterCapture_Flushes() throws {
        let (sut, _, fileManager, dispatchQueueWrapper) = try getSut()

        defer { fileManager.deleteAllEnvelopes() }

        for _ in 0..<10 {
            sut.send(envelope: SentryEnvelope(event: Event()))
            // Wait until the dispath queue drains to confirm the envelope is stored
            waitForEnvelopeToBeStored(dispatchQueueWrapper)

            XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")

            XCTAssertEqual(fileManager.getAllEnvelopes().count, 0)
        }
    }

    func testFlushTimesOut_RequestManagerNeverFinishes_FlushingWorksNextTime() throws {
        let (sut, requestManager, _, dispatchQueueWrapper) = try getSut()

        requestManager.waitForResponseDispatchGroup = true
        requestManager.responseDispatchGroup.enter()

        requestManager.returnResponse(response: nil)
        sut.send(envelope: SentryEnvelope(event: Event()))
        // Wait until the dispath queue drains to confirm the envelope is stored
        waitForEnvelopeToBeStored(dispatchQueueWrapper)
        requestManager.returnResponse(response: HTTPURLResponse())

        XCTAssertEqual(sut.flush(0.0), .timedOut, "Flush should time out.")

        requestManager.responseDispatchGroup.leave()

        XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")
    }

    func testFlush_CalledMultipleTimes_ImmediatelyReturnsFalse() throws {
        let (sut, requestManager, _, dispatchQueueWrapper) = try getSut()

        // This must be long enough that all the threads we start below get to run
        // while the first call to flush is still blocking
        let flushTimeout = 10.0
        requestManager.waitForResponseDispatchGroup = true
        requestManager.responseDispatchGroup.enter()
        
        requestManager.returnResponse(response: nil)
        for _ in 0..<30 {
            sut.send(envelope: SentryEnvelope(event: Event()))
        }
        // Wait until the dispatch queue drains to confirm the envelope is stored
        waitForEnvelopeToBeStored(dispatchQueueWrapper)
        requestManager.returnResponse(response: HTTPURLResponse())

        let initialFlushCallExpectation = XCTestExpectation(description: "Initial flush call should succeed")
        initialFlushCallExpectation.assertForOverFulfill = true

        let ensureFlushingExpectation = XCTestExpectation(description: "Ensure flushing is called")
        ensureFlushingExpectation.assertForOverFulfill = true

        let ensureFlushingQueue = DispatchQueue(label: "First flushing")

        sut.setStartFlushCallback {
            ensureFlushingExpectation.fulfill()
        }

        ensureFlushingQueue.async {
            XCTAssertEqual(.success, sut.flush(flushTimeout), "Initial call to flush should succeed")
            initialFlushCallExpectation.fulfill()
        }

        // Ensure transport is flushing.
        wait(for: [ensureFlushingExpectation], timeout: 10.0)

        // Now the transport should also have left the synchronized block, and the
        // flush should return immediately.

        let loopCount = 2
        let parallelFlushCallsExpectation = XCTestExpectation(description: "Parallel flush calls should return immediately")
        parallelFlushCallsExpectation.expectedFulfillmentCount = loopCount
        parallelFlushCallsExpectation.assertForOverFulfill = true

        let initiallyInactiveQueue = DispatchQueue(label: "testFlush_CalledMultipleTimes_ImmediatelyReturnsFalse", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])
        for _ in 0..<loopCount {

            initiallyInactiveQueue.async {
                for _ in 0..<10 {
                    XCTAssertEqual(.alreadyFlushing, sut.flush(flushTimeout), "Flush should have returned immediately")
                }

                parallelFlushCallsExpectation.fulfill()
            }
        }

        initiallyInactiveQueue.activate()
        wait(for: [parallelFlushCallsExpectation], timeout: 10.0)

        requestManager.responseDispatchGroup.leave()

        // The initial call to flush is blocking and will take some time to finish.
        // Therefore, we wait at the end of the test.
        wait(for: [initialFlushCallExpectation], timeout: 10.0)
    }

    // We use the test name as part of the DSN to ensure that each test runs in isolation.
    // As we use real dispatch queues it could happen that some delayed operations don't finish before
    // the next test starts. Deleting the envelopes at the end or beginning of the test doesn't help,
    // when some operation is still in flight.
    private func getSut(testName: String = #function) throws -> (SentryHttpTransport, TestRequestManager, SentryFileManager, SentryDispatchQueueWrapper) {
        let options = Options()
        options.debug = true
        options.dsn = TestConstants.dsnAsString(username: "SentryHttpTransportFlushIntegrationTests.\(testName)")

        let fileManager = try SentryFileManager(options: options)
        fileManager.deleteAllEnvelopes()

        let requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
        requestManager.returnResponse(response: HTTPURLResponse())

        let currentDate = SentryDefaultCurrentDateProvider()

        let rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: currentDate), andRateLimitParser: RateLimitParser(currentDateProvider: currentDate), currentDateProvider: currentDate)
        
        let dispatchQueueWrapper = SentryDispatchQueueWrapper()

        return (SentryHttpTransport(
            dsn: try XCTUnwrap(options.parsedDsn),
            sendClientReports: options.sendClientReports,
            cachedEnvelopeSendDelay: 0.0,
            dateProvider: SentryDefaultCurrentDateProvider(),
            fileManager: fileManager,
            requestManager: requestManager,
            requestBuilder: TestNSURLRequestBuilder(),
            rateLimits: rateLimits,
            envelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits),
            dispatchQueueWrapper: dispatchQueueWrapper
        ), requestManager, fileManager, dispatchQueueWrapper)
    }

    private func waitForEnvelopeToBeStored(_ dispatchQueueWrapper: SentryDispatchQueueWrapper) {
        // Wait until the dispath queue drains to confirm the envelope is stored
        let expectation = XCTestExpectation(description: "Envelope sent")
        dispatchQueueWrapper.dispatchAsync {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
}
