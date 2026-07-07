@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDispatchSourceWrapperTests: XCTestCase {

    func testDispatchSourceWrapper_Repeats() throws {

        let nanoInterval: Int = 1_000_000 // 1 millisecond
        let leeway: Int = 100 // 100 nanoseconds

        let dateProvider = SentryDefaultCurrentDateProvider()
        var eventInvocations = [UInt64]()
        let expectedEventInvocationCount = 100

        let expectation = self.expectation(description: "EventHandler Called")
        let queue = SentryDispatchQueueWrapper()

        let sut = SentryDispatchSourceWrapper(interval: nanoInterval, leeway: leeway, queue: queue, eventHandler: {
            eventInvocations.append(dateProvider.systemTime())

            if eventInvocations.count == expectedEventInvocationCount {
                expectation.fulfill()
            }
        })

        wait(for: [expectation], timeout: 5)
        sut.cancel()
        // Wait for an event handler that's already running or queued before reading eventInvocations.
        // This doesn't bound the invocation count; it only makes the assertions use a stable snapshot.
        let recordedEventInvocations = queue.queue.sync { eventInvocations }

        // There are usually more than 100 invocations, because calling cancel on the DispatchSource only
        // cancels further invocations, but not the one that's already in progress and it can take a little while until we
        // cancel it after fulfilling the expectation. CI can also delay the test thread before it cancels the source.
        XCTAssertGreaterThanOrEqual(
            recordedEventInvocations.count,
            expectedEventInvocationCount,
            "Event handler must be called at least \(expectedEventInvocationCount) times, but was called \(recordedEventInvocations.count) times"
        )

        // We have to be quite lenient with the leeway, because GH actions can be quite slow sometimes.
        let assertionLeeway = 10_000_000 // 10 milliseconds

        // Verify that the timing between consecutive events respects the interval and leeway
        // We only require 80% of the intervals to be accurate since CI can sometimes pause execution
        // briefly, but we still want to verify the timer is generally working correctly.
        let minExpectedInterval = nanoInterval - assertionLeeway
        let maxExpectedInterval = nanoInterval + assertionLeeway
        var accurateIntervals = 0

        for i in 1..<recordedEventInvocations.count {
            let timeDifference = recordedEventInvocations[i] - recordedEventInvocations[i - 1]

            if timeDifference >= minExpectedInterval && timeDifference <= maxExpectedInterval {
                accurateIntervals += 1
            }
        }

        let totalIntervals = recordedEventInvocations.count - 1
        let requiredAccurateIntervals = max(1, Int(Double(totalIntervals) * 0.8)) // At least 80%

        XCTAssertGreaterThanOrEqual(accurateIntervals, requiredAccurateIntervals,
            "Only \(accurateIntervals) out of \(totalIntervals) intervals were accurate (expected >= \(requiredAccurateIntervals)). Expected interval: \(nanosToSeconds(minExpectedInterval)) - \(nanosToSeconds(maxExpectedInterval))")
    }

    private func nanosToSeconds(_ nanoseconds: Int) -> String {
        return String(format: "%.3f s", Double(nanoseconds) / 1_000_000_000)
    }

}
