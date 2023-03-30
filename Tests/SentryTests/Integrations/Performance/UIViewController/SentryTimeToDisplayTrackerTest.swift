import Foundation
import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryTimeToDisplayTrackerTest: XCTestCase {

    private class Fixture {
        let dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()
        var tracer: SentryTracer {  SentryTracer(transactionContext: TransactionContext(operation: "Test Operation"), hub: nil) }

        var displayLinkWrapper = TestDisplayLinkWrapper()
        var framesTracker: SentryFramesTracker

        init() {
            framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper)
            framesTracker.start()
        }

        func getSut(for controller: UIViewController, waitForFullDisplay: Bool) -> SentryTimeToDisplayTracker {
            return SentryTimeToDisplayTracker(for: controller, framesTracker: framesTracker, waitForFullDisplay: waitForFullDisplay)
        }
    }

    private let fixture = Fixture()

    override func setUp() {
        super.setUp()
        CurrentDate.setCurrentDateProvider(fixture.dateProvider)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testReportInitialDisplay_notWaitingFullDisplay() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        let tracer = fixture.tracer

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 1)
        XCTAssertEqual(Dynamic(fixture.framesTracker).listeners.count, 1)

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        XCTAssertEqual(ttidSpan.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(ttidSpan.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan.isFinished)
        XCTAssertEqual(ttidSpan.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan.operation, SentrySpanOperationUILoadInitialDisplay)

        XCTAssertEqual(Dynamic(fixture.framesTracker).listeners.count, 0)
    }

    func testReportNewFrame_notReadyToDisplay() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let tracer = fixture.tracer

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        XCTAssertEqual(ttidSpan.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertNil(ttidSpan.timestamp)
        XCTAssertFalse(ttidSpan.isFinished)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(ttidSpan.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan.isFinished)
    }

    func testreportInitialDisplay_waitForFullDisplay() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 2)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan?.isFinished ?? false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(tracer.children.count, 2)
    }

    func testreportFullDisplay_notWaitingForFullDisplay() {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        sut.reportFullyDisplayed()

        XCTAssertNil(sut.fullDisplaySpan)
        XCTAssertEqual(tracer.children.count, 1)
    }

    func testreportFullDisplay_waitingForFullDisplay() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 10))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        tracer.finish()

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, Date(timeIntervalSince1970: 11))
        XCTAssertEqual(sut.fullDisplaySpan?.status, .ok)

        XCTAssertEqual(sut.fullDisplaySpan?.spanDescription, "UIViewController full display")
        XCTAssertEqual(sut.fullDisplaySpan?.operation, SentrySpanOperationUILoadFullDisplay)
    }

    func testReportFullDisplay_waitingForFullDisplay_notReadyToDisplay() {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        XCTAssertFalse(sut.fullDisplaySpan?.isFinished ?? true)
    }

    func testReportFullDisplay_expires() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 10))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.fullDisplaySpan?.finish(status: .deadlineExceeded)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 13))
        tracer.finish()

        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(sut.fullDisplaySpan?.spanDescription, "UIViewController full display - Deadline Exceeded")
    }

    func testCheckInitialTime() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        fixture.dateProvider.driftTimeForEveryRead = true

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, tracer.startTimestamp)
        XCTAssertEqual(sut.initialDisplaySpan?.startTimestamp, tracer.startTimestamp)
    }

    func testFullDisplay_reportedBefore_initialDisplay() {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer
        sut.start(for: tracer)
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportFullyDisplayed()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportReadyToDisplay()
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(sut.initialDisplaySpan?.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, sut.initialDisplaySpan?.timestamp)
    }
}

#endif
