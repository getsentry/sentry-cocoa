@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDispatchSourceWrapperTests: XCTestCase {

    func testDispatchSourceWrapper_Repeats() throws {

        let nanoInterval: UInt64 = 100_000_000 // 0.1 second
        let leeway: UInt64 = 10_000_000 // 0.01 second

        let dateProvider = SentryDefaultCurrentDateProvider()
        var eventInvocations = [UInt64]()
        let expectedEventInvocationCount = 10

        let expectation = self.expectation(description: "EventHandler Called")

        let sut = SentryDispatchSourceWrapper(interval: nanoInterval, leeway: leeway, queue: SentryDispatchQueueWrapper(), eventHandler: {
            eventInvocations.append(dateProvider.systemTime())

            if eventInvocations.count == expectedEventInvocationCount {
                expectation.fulfill()
            }
        })
        defer { sut.cancel() }

        wait(for: [expectation], timeout: 5)

        // There might be more than 10 invocations, because calling cancel on the DispatchSource only
        // cancels further invocations, but not the one that's already in progress, but there must not
        // be more than 11.
        let expectedMaxEventInvocationCount = expectedEventInvocationCount + 1
        XCTAssertGreaterThanOrEqual(
            eventInvocations.count,
            expectedEventInvocationCount,
            "Event handler must be called at least \(expectedEventInvocationCount) times, but was called \(eventInvocations.count) times"
        )
        XCTAssertLessThanOrEqual(
            eventInvocations.count,
             expectedMaxEventInvocationCount,
             "Event handler must be called at most \(expectedMaxEventInvocationCount) times, but was called \(eventInvocations.count) times"
        )

        // We have to be quite lenient with the leeway, because GH actions can be quite slow sometimes.
        let assertionLeeway = leeway * 5 // 0.05 seconds

        // Verify that the timing between consecutive events respects the interval and leeway
        // We only require 80% of the intervals to be accurate since CI can sometimes pause execution
        // briefly, but we still want to verify the timer is generally working correctly.
        let minExpectedInterval = nanoInterval - assertionLeeway
        let maxExpectedInterval = nanoInterval + assertionLeeway
        var accurateIntervals = 0
        
        for i in 1..<eventInvocations.count {
            let timeDifference = eventInvocations[i] - eventInvocations[i - 1]
            
            if timeDifference >= minExpectedInterval && timeDifference <= maxExpectedInterval {
                accurateIntervals += 1
            }
        }
        
        let totalIntervals = eventInvocations.count - 1
        let requiredAccurateIntervals = max(1, Int(Double(totalIntervals) * 0.8)) // At least 80%
        
        XCTAssertGreaterThanOrEqual(accurateIntervals, requiredAccurateIntervals,
            "Only \(accurateIntervals) out of \(totalIntervals) intervals were accurate (expected >= \(requiredAccurateIntervals)). Expected interval: \(nanosToSeconds(minExpectedInterval)) - \(nanosToSeconds(maxExpectedInterval))")
    }

    private func nanosToSeconds(_ nanoseconds: UInt64) -> String {
        return String(format: "%.3f s", Double(nanoseconds) / 1_000_000_000)
    }

}
