import Foundation
import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryTimeToDisplayTrackerTest: XCTestCase {

    private class Fixture {
        let dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()
        var tracer: SentryTracer {  SentryTracer(transactionContext: TransactionContext(operation: "Test Operation"), hub: nil) }
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

    func testreportInitialDisplay_notWaitingFullDisplay() throws {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        XCTAssertEqual(ttidSpan.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()

        XCTAssertEqual(ttidSpan.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan.isFinished)
        XCTAssertEqual(ttidSpan.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan.operation, SentrySpanOperationUILoadInitialDisplay)
    }

    func testreportInitialDisplay_waitForFullDisplay() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 2)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan?.isFinished ?? false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(tracer.children.count, 2)
    }

    func testreportFullDisplay_noWaitingForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        sut.start(for: tracer)
        sut.reportFullyDisplayed()

        XCTAssertNil(sut.fullDisplaySpan)
        XCTAssertEqual(tracer.children.count, 1)
    }

    func testreportFullDisplay_waitingForFullDisplay() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(sut.fullDisplaySpan?.status, .ok)

        XCTAssertEqual(sut.fullDisplaySpan?.spanDescription, "UIViewController full display")
        XCTAssertEqual(sut.fullDisplaySpan?.operation, SentrySpanOperationUILoadFullDisplay)
    }

    func test_checkInitialTime() {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        fixture.dateProvider.driftTimeForEveryRead = true

        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        sut.start(for: tracer)

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, tracer.startTimestamp)
        XCTAssertEqual(sut.initialDisplaySpan?.startTimestamp, tracer.startTimestamp)
    }

    func test_fullDisplay_reportedBefore_initialDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer
        sut.start(for: tracer)
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let ttidSpan = tracer.children.first

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportFullyDisplayed()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(sut.initialDisplaySpan?.timestamp, ttidSpan?.timestamp)
    }
}

#endif
