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
        XCTAssertEqual(try XCTUnwrap(activities.element(at: beforeWaitingIndex + 1)), .afterWaiting)
    }

    func testStart_whenMainRunLoopIdle_shouldNotWakeUpRunLoop() {
        // -- Arrange --
        // Not waking up an idle app is the reason this observer exists. A display link would wake
        // up the run loop for every frame, which is 30 times or more in the time this waits.
        let idleDuration: TimeInterval = 0.5
        let wakeupsWithoutObserver = countMainRunLoopWakeups(during: idleDuration)

        let sut = SentryMainRunLoopActivityObserver()
        var reportedActivities = 0
        sut.start { _ in reportedActivities += 1 }
        defer { sut.stop() }

        // -- Act --
        let wakeupsWithObserver = countMainRunLoopWakeups(during: idleDuration)

        // -- Assert --
        XCTAssertGreaterThan(reportedActivities, 0)
        // The test host wakes up the run loop a few times on its own, and not equally often in both
        // intervals.
        XCTAssertLessThanOrEqual(wakeupsWithObserver, wakeupsWithoutObserver + 5)
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

    private func countMainRunLoopWakeups(during duration: TimeInterval) -> Int {
        var wakeups = 0
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue, true, 0) { _, _ in
            wakeups += 1
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        defer { CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes) }

        RunLoop.main.run(until: Date().addingTimeInterval(duration))

        return wakeups
    }
}
#endif
