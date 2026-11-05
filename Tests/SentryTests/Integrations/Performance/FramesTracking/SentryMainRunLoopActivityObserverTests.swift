#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(tvOS)
final class SentryMainRunLoopActivityObserverTests: XCTestCase {

    func testStart_whenMainRunLoopRuns_shouldReportActivitiesOfEachIteration() {
        // -- Arrange --
        let sut = SentryMainRunLoopActivityObserver()
        var activities: [CFRunLoopActivity] = []
        sut.start { activities.append($0) }
        defer { sut.stop() }

        // -- Act --
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // -- Assert --
        // Running the run loop from here enters and exits it, and it waits for the date to pass.
        XCTAssertEqual(activities.first, .entry)
        XCTAssertEqual(activities.last, .exit)
        XCTAssertTrue(activities.contains(.beforeTimers))
        XCTAssertTrue(activities.contains(.beforeWaiting))
        XCTAssertTrue(activities.contains(.afterWaiting))
    }

    func testStart_whenRunLoopWaits_shouldReportAfterWaitingRightAfterBeforeWaiting() throws {
        // -- Arrange --
        let sut = SentryMainRunLoopActivityObserver()
        var activities: [CFRunLoopActivity] = []
        sut.start { activities.append($0) }
        defer { sut.stop() }

        // -- Act --
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // -- Assert --
        // The frames tracker relies on nothing being reported while the run loop waits.
        let beforeWaitingIndex = try XCTUnwrap(activities.firstIndex(of: .beforeWaiting))
        XCTAssertEqual(activities[beforeWaitingIndex + 1], .afterWaiting)
    }

    func testStop_whenMainRunLoopRuns_shouldNotReportActivities() {
        // -- Arrange --
        let sut = SentryMainRunLoopActivityObserver()
        var activities: [CFRunLoopActivity] = []
        sut.start { activities.append($0) }

        // -- Act --
        sut.stop()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // -- Assert --
        XCTAssertEqual(activities, [])
    }

    func testStart_whenCalledTwice_shouldKeepReportingToFirstHandlerOnly() {
        // -- Arrange --
        let sut = SentryMainRunLoopActivityObserver()
        var firstHandlerCalls = 0
        var secondHandlerCalls = 0
        sut.start { _ in firstHandlerCalls += 1 }
        sut.start { _ in secondHandlerCalls += 1 }
        defer { sut.stop() }

        // -- Act --
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        // -- Assert --
        XCTAssertGreaterThan(firstHandlerCalls, 0)
        XCTAssertEqual(secondHandlerCalls, 0)
    }
}
#endif
