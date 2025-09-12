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

        // Verify that the timing between consecutive events respects the interval and leeway
        for i in 1..<eventInvocations.count {
            let timeDifference = eventInvocations[i] - eventInvocations[i - 1]
            let minExpectedInterval = nanoInterval - leeway  // 90_000_000 ns (0.09 seconds)
            let maxExpectedInterval = nanoInterval + leeway  // 110_000_000 ns (0.11 seconds)
            
            XCTAssertGreaterThanOrEqual(timeDifference, minExpectedInterval,
                "Event \(i) occurred too soon. Time difference: \(timeDifference) ns, expected >= \(minExpectedInterval) ns")
            XCTAssertLessThanOrEqual(timeDifference, maxExpectedInterval,
                "Event \(i) occurred too late. Time difference: \(timeDifference) ns, expected <= \(maxExpectedInterval) ns")
        }
    }

}
