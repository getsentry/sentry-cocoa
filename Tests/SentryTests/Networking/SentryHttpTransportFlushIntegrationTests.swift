@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryHttpTransportFlushIntegrationTests: XCTestCase {

    private let flushTimeout: TimeInterval = 5.0

    func testFlush_WhenNoEnvelopes_BlocksAndFinishes() throws {

        let (sut, _, _) = try getSut(testName: "\(#function)")

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
        let (sut, requestManager, _) = try getSut(testName: "\(#function)")

        requestManager.returnResponse(response: nil)

        sut.send(envelope: SentryEnvelope(event: Event()))
        sut.send(envelope: SentryEnvelope(event: Event()))

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
        let (sut, _, fileManager) = try getSut(testName: "\(#function)")

        defer { fileManager.deleteAllEnvelopes() }

        for _ in 0..<10 {
            sut.send(envelope: SentryEnvelope(event: Event()))

            XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")

            XCTAssertEqual(fileManager.getAllEnvelopes().count, 0)
        }
    }

    func testFlushTimesOut_RequestManagerNeverFinishes_FlushingWorksNextTime() throws {
        let (sut, requestManager, _) = try getSut(testName: "\(#function)")

        requestManager.returnResponse(response: nil)
        sut.send(envelope: SentryEnvelope(event: Event()))
        requestManager.returnResponse(response: HTTPURLResponse())

        requestManager.waitForResponseDispatchGroup = true
        requestManager.responseDispatchGroup.enter()

        XCTAssertEqual(sut.flush(0.0), .timedOut, "Flush should time out.")

        requestManager.responseDispatchGroup.leave()

        XCTAssertEqual(sut.flush(self.flushTimeout), .success, "Flush should not time out.")
    }

    func testFlush_CalledMultipleTimes_ImmediatelyReturnsFalse() throws {
        let (sut, requestManager, _) = try getSut(testName: "\(#function)")

        requestManager.returnResponse(response: nil)
        for _ in 0..<30 {
            sut.send(envelope: SentryEnvelope(event: Event()))
        }
        requestManager.returnResponse(response: HTTPURLResponse())

        let flushTimeout = 0.1
        requestManager.waitForResponseDispatchGroup = true
        requestManager.responseDispatchGroup.enter()

        let allFlushCallsGroup = DispatchGroup()
        let ensureFlushingGroup = DispatchGroup()
        let ensureFlushingQueue = DispatchQueue(label: "First flushing")

        sut.setStartFlushCallback {
            ensureFlushingGroup.leave()
        }

        allFlushCallsGroup.enter()
        ensureFlushingGroup.enter()
        ensureFlushingQueue.async {
            XCTAssertEqual(.timedOut, sut.flush(flushTimeout))
            requestManager.responseDispatchGroup.leave()
            allFlushCallsGroup.leave()
        }

        // Ensure transport is flushing.
        ensureFlushingGroup.waitWithTimeout()

        // Now the transport should also have left the synchronized block, and the
        // flush should return immediately.

        let initiallyInactiveQueue = DispatchQueue(label: "testFlush_CalledMultipleTimes_ImmediatelyReturnsFalse", qos: .userInitiated, attributes: [.concurrent, .initiallyInactive])
        for _ in 0..<2 {
            allFlushCallsGroup.enter()
            initiallyInactiveQueue.async {
                for _ in 0..<10 {
                    XCTAssertEqual(.alreadyFlushing, sut.flush(flushTimeout), "Flush should have returned immediately")
                }

                allFlushCallsGroup.leave()
            }
        }

        initiallyInactiveQueue.activate()
        allFlushCallsGroup.waitWithTimeout()
    }

    // We use the test name as part of the DSN to ensure that each test runs in isolation.
    // As we use real dispatch queues it could happen that some delayed operations don't finish before
    // the next test starts. Deleting the envelopes at the end or beginning of the test doesn't help,
    // when some operation is still in flight.
    private func getSut(testName: String) throws -> (SentryHttpTransport, TestRequestManager, SentryFileManager) {
        let options = Options()
        options.debug = true
        options.dsn = TestConstants.dsnAsString(username: "SentryHttpTransportFlushIntegrationTests.\(testName)")

        let fileManager = try SentryFileManager(options: options)
        fileManager.deleteAllEnvelopes()

        let requestManager = TestRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral))
        requestManager.returnResponse(response: HTTPURLResponse())

        let currentDate = SentryDefaultCurrentDateProvider()

        let rateLimits = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: currentDate), andRateLimitParser: RateLimitParser(currentDateProvider: currentDate), currentDateProvider: currentDate)

        return (SentryHttpTransport(
            options: options,
            cachedEnvelopeSendDelay: 0.0,
            dateProvider: SentryDefaultCurrentDateProvider(),
            fileManager: fileManager,
            requestManager: requestManager,
            requestBuilder: TestNSURLRequestBuilder(),
            rateLimits: rateLimits,
            envelopeRateLimit: EnvelopeRateLimit(rateLimits: rateLimits),
            dispatchQueueWrapper: SentryDispatchQueueWrapper()
        ), requestManager, fileManager)
    }

}
