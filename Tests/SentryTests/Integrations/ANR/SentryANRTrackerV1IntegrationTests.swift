@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

final class SentryANRTrackerV1IntegrationTests: XCTestCase {

    /// This uses an actual dispatch queue and a thread wrapper so the thread sanitizer can find threading problems in the implementation.
    /// It has no assertions on purpose. To test the thread safety locally, enable the thread sanitizer in the test plan.
    func testWithActualDispatchQueueAndThreadWrapper() {
        let expectation = XCTestExpectation(description: "ANR Tracker")

        let listener = SentryANRTrackerTestDelegate()

        let anrTracker: SentryANRTracker = SentryANRTrackerV1(
            timeoutInterval: 0.01,
            crashWrapper: TestSentryCrashWrapper.sharedInstance(),
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            threadWrapper: SentryThreadWrapper()) as! SentryANRTracker

        anrTracker.add(listener: listener)

        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            anrTracker.clear()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
