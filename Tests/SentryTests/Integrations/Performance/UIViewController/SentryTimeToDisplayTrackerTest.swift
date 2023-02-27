import Foundation
import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryTimeToDisplayTrackerTest: XCTestCase {

    private class Fixture {
        let dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()
        let tracer = SentryTracer(transactionContext: TransactionContext(operation: "Test Operation"), hub: nil)
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

    func testRegisterInitialDisplay_notWaitingFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addMiddleware(sut)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.registerInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(ttidSpan?.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan?.operation, SentrySpanOperationUILoadTTID)
    }

    func testRegisterInitialDisplay_waitForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addMiddleware(sut)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.registerInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertFalse(ttidSpan?.isFinished ?? true)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.registerFullDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(tracer.children.count, 1)
    }

    func testRegisterFullDisplay_noWaitingForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        tracer.addMiddleware(sut)
        sut.registerFullDisplay()

        let additionalSpans = sut.createAdditionalSpans(forTrace: tracer)
        XCTAssertEqual(additionalSpans.count, 0)
    }

    func testRegisterFullDisplay_waitingForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        tracer.addMiddleware(sut)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.registerFullDisplay()

        let additionalSpans = sut.createAdditionalSpans(forTrace: tracer)
        XCTAssertEqual(additionalSpans.count, 1)
        XCTAssertEqual(additionalSpans[0].startTimestamp, sut.startDate)
        XCTAssertEqual(additionalSpans[0].timestamp, fixture.dateProvider.date())
        XCTAssertEqual(additionalSpans[0].status, .ok)

        XCTAssertEqual(additionalSpans[0].spanDescription, "UIViewController full display")
        XCTAssertEqual(additionalSpans[0].operation, SentrySpanOperationUILoadTTFD)
    }

    func testWaiting_timeout() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        tracer.addMiddleware(sut)

        let ttidSpan = tracer.children.first
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.registerInitialDisplay()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))

        sut.tracerDidTimeout(tracer)
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 11))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
    }

    func test_fullDisplay_reportedBefore_initialDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addMiddleware(sut)

        let ttidSpan = tracer.children.first

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.registerFullDisplay()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.registerInitialDisplay()

        let additionalSpans = sut.createAdditionalSpans(forTrace: tracer)
        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(additionalSpans.first?.timestamp, ttidSpan?.timestamp)
    }

    func test_stopWaitingFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addMiddleware(sut)

        let ttidSpan = tracer.children.first

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.registerInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertFalse(ttidSpan?.isFinished ?? true)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.stopWaitingFullDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(tracer.children.count, 1)
    }
}

#endif
