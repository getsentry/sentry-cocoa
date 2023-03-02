import Foundation
import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryTimeToDisplayTrackerTest: XCTestCase {

    private class Fixture {
        let dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()
        let tracer = SentryTracer(transactionContext: TransactionContext(operation: "Test Operation"), hub: nil)
        let spanCreation: SpanCreationCallback = { op, desc in
            return SentrySpan(context: SpanContext(trace: SentryId(), spanId: SpanId(), parentId: nil, operation: op, spanDescription: desc, sampled: .yes))
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

    func testreportInitialDisplay_notWaitingFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addExtension(sut)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(ttidSpan?.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan?.operation, SentrySpanOperationUILoadInitialDisplay)
    }

    func testreportInitialDisplay_waitForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addExtension(sut)
        XCTAssertEqual(tracer.children.count, 1)

        let ttidSpan = tracer.children.first
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertFalse(ttidSpan?.isFinished ?? true)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullDisplay()

        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
        XCTAssertEqual(tracer.children.count, 1)
    }

    func testreportFullDisplay_noWaitingForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: false)
        let tracer = fixture.tracer

        tracer.addExtension(sut)
        sut.reportFullDisplay()

        let additionalSpans = sut.tracerAdditionalSpan({ op, _ in
            return SentrySpan(context: SpanContext(operation: op))
        })
        XCTAssertEqual(additionalSpans.count, 0)
    }

    func testreportFullDisplay_waitingForFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        tracer.addExtension(sut)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullDisplay()

        let additionalSpans = sut.tracerAdditionalSpan(fixture.spanCreation)
        XCTAssertEqual(additionalSpans.count, 1)
        XCTAssertEqual(additionalSpans[0].startTimestamp, sut.startDate)
        XCTAssertEqual(additionalSpans[0].timestamp, fixture.dateProvider.date())
        XCTAssertEqual(additionalSpans[0].status, .ok)

        XCTAssertEqual(additionalSpans[0].spanDescription, "UIViewController full display")
        XCTAssertEqual(additionalSpans[0].operation, SentrySpanOperationUILoadFullDisplay)
    }

    func testWaiting_timeout() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        tracer.addExtension(sut)

        let ttidSpan = tracer.children.first
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportInitialDisplay()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))

        sut.tracerDidTimeout()
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 11))
        XCTAssertTrue(ttidSpan?.isFinished ?? false)
    }

    func test_fullDisplay_reportedBefore_initialDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addExtension(sut)

        let ttidSpan = tracer.children.first

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportFullDisplay()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportInitialDisplay()

        let additionalSpans = sut.tracerAdditionalSpan(fixture.spanCreation)
        XCTAssertEqual(ttidSpan?.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(additionalSpans.first?.timestamp, ttidSpan?.timestamp)
    }

    func test_stopWaitingFullDisplay() {
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true)
        let tracer = fixture.tracer

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        tracer.addExtension(sut)

        let ttidSpan = tracer.children.first

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()

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
