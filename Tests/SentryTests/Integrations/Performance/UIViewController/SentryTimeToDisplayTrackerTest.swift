import Foundation
import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

class SentryTimeToDisplayTrackerTest: XCTestCase {

    private class Fixture {
        let dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()
        let timerFactory = TestSentryNSTimerFactory()

        var displayLinkWrapper = TestDisplayLinkWrapper()
        var framesTracker: SentryFramesTracker

        init() {
            framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(),
                                                notificationCenter: TestNSNotificationCenterWrapper(), keepDelayedFramesDuration: 0)
            SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
            framesTracker.start()
        }

        func getSut(for controller: UIViewController, waitForFullDisplay: Bool) -> SentryTimeToDisplayTracker {
            return SentryTimeToDisplayTracker(for: controller, waitForFullDisplay: waitForFullDisplay, dispatchQueueWrapper: SentryDispatchQueueWrapper())
        }
        
        func getTracer() throws -> SentryTracer {
            let options = Options()
            let hub = TestHub(client: SentryClient(options: options, fileManager: try TestFileManager(options: options), deleteOldEnvelopeItems: false), andScope: nil)
            return SentryTracer(transactionContext: TransactionContext(operation: "ui.load"), hub: hub, configuration: SentryTracerConfiguration(block: {
                $0.waitForChildren = true
                $0.timerFactory = self.timerFactory
            }))
        }
    }

    private lazy var fixture = Fixture()

    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.dateProvider
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testReportInitialDisplay_notWaitingForFullDisplay() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 1)
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 1)

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        XCTAssertEqual(ttidSpan.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()
        XCTAssertNil(ttidSpan.timestamp)
        XCTAssertFalse(ttidSpan.isFinished)
        
        fixture.displayLinkWrapper.normalFrame()
        tracer.finish()

        XCTAssertEqual(ttidSpan.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(ttidSpan.isFinished, true)
        XCTAssertEqual(ttidSpan.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan.operation, SentrySpanOperationUILoadInitialDisplay)
        XCTAssertEqual(ttidSpan.origin, "auto.ui.time_to_display")

        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }

    func testReportInitialDisplay_waitForFullDisplay() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 2)

        let ttidSpan = sut.initialDisplaySpan
        XCTAssertEqual(ttidSpan?.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertEqual(ttidSpan?.isFinished, true)
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 9))
        XCTAssertNil(tracer.measurements["time_to_initial_display"])

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()
        
        // TTFD not reported yet cause we wait for the next frame
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, ttidSpan?.startTimestamp)
        XCTAssertNil(sut.fullDisplaySpan?.timestamp)
        XCTAssertNil(tracer.measurements["time_to_full_display"])
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 1)
    }

    func testReportFullDisplay_notWaitingForFullDisplay() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        sut.reportFullyDisplayed()

        XCTAssertNil(sut.fullDisplaySpan)
        XCTAssertEqual(tracer.children.count, 1)
        XCTAssertNil(tracer.measurements["time_to_full_display"])
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }
    
    func testReportFullDisplay_waitingForFullDisplay() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 10))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        fixture.displayLinkWrapper.normalFrame()
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 13))
        tracer.finish()

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, Date(timeIntervalSince1970: 12))
        XCTAssertEqual(sut.fullDisplaySpan?.status, .ok)

        XCTAssertEqual(sut.fullDisplaySpan?.spanDescription, "UIViewController full display")
        XCTAssertEqual(sut.fullDisplaySpan?.operation, SentrySpanOperationUILoadFullDisplay)
        XCTAssertEqual(sut.fullDisplaySpan?.origin, "manual.ui.time_to_display")
        
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }
    
    func testWaitingForFullDisplay_ReportFullDisplayBeforeInitialDisplay() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)

        let tracer = try fixture.getTracer()
        sut.start(for: tracer)

        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()
        
        fixture.displayLinkWrapper.normalFrame()

        XCTAssertFalse(try XCTUnwrap(sut.fullDisplaySpan?.isFinished))
        XCTAssertFalse(try XCTUnwrap(sut.initialDisplaySpan?.isFinished))
        
        sut.reportInitialDisplay()
        
        XCTAssertFalse(try XCTUnwrap(sut.fullDisplaySpan?.isFinished))
        XCTAssertFalse(try XCTUnwrap(sut.initialDisplaySpan?.isFinished))
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        fixture.displayLinkWrapper.normalFrame()
        tracer.finish()
        
        let initialDisplaySpan = try XCTUnwrap(sut.initialDisplaySpan)
        let fullDisplaySpan = try XCTUnwrap(sut.fullDisplaySpan)
        XCTAssert(initialDisplaySpan.isFinished)
        XCTAssertEqual(initialDisplaySpan.timestamp, Date(timeIntervalSince1970: 12))
        XCTAssertEqual(initialDisplaySpan.status, .ok)
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 3_000)
        
        XCTAssert(fullDisplaySpan.isFinished)
        XCTAssertEqual(fullDisplaySpan.timestamp, Date(timeIntervalSince1970: 12))
        XCTAssertEqual(fullDisplaySpan.status, .ok)
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }
    
    func testTracerFinishesBeforeReportInitialDisplay_FinishesInitialDisplaySpan() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)
        XCTAssertEqual(tracer.children.count, 1)
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 1)

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        XCTAssertEqual(ttidSpan.startTimestamp, fixture.dateProvider.date())

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        
        tracer.finish()

        XCTAssertEqual(ttidSpan.timestamp, fixture.dateProvider.date())
        XCTAssertEqual(ttidSpan.isFinished, true)
        XCTAssertEqual(ttidSpan.spanDescription, "UIViewController initial display")
        XCTAssertEqual(ttidSpan.status, .ok)

        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }

    func testCheckInitialTime() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        fixture.dateProvider.driftTimeForEveryRead = true

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        XCTAssertNotNil(sut.fullDisplaySpan)
        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, tracer.startTimestamp)
        XCTAssertEqual(sut.initialDisplaySpan?.startTimestamp, tracer.startTimestamp)
    }
    
    func testReportFullyDisplayed_AfterTracerTimesOut() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let tracer = try fixture.getTracer()
        
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 10))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))

        // Timeout for tracer times out
        fixture.timerFactory.fire()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        sut.reportFullyDisplayed()
        
        let ttidSpan = sut.initialDisplaySpan
        XCTAssertEqual(ttidSpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(ttidSpan?.status, .ok)
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 1_000)
        
        let ttfdSpan = sut.fullDisplaySpan
        XCTAssertEqual(ttfdSpan?.startTimestamp, ttidSpan?.startTimestamp)
        XCTAssertEqual(ttfdSpan?.timestamp, ttidSpan?.timestamp)
        XCTAssertEqual(ttfdSpan?.status, .deadlineExceeded)
        XCTAssertEqual(ttfdSpan?.spanDescription, "UIViewController full display - Deadline Exceeded")
        XCTAssertEqual(ttfdSpan?.operation, SentrySpanOperationUILoadFullDisplay)
        XCTAssertEqual(ttfdSpan?.origin, "manual.ui.time_to_display")
        
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 1_000)
    }
    
    func testReportFullyDisplayed_GetsDispatchedOnMainQueue() {
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        
        let sut = SentryTimeToDisplayTracker(for: UIViewController(), waitForFullDisplay: true, dispatchQueueWrapper: dispatchQueueWrapper)
        
        let invocationsBefore = dispatchQueueWrapper.blockOnMainInvocations.count
        sut.reportFullyDisplayed()
        
        let expectedInvocations = invocationsBefore + 1
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, expectedInvocations, "reportFullyDisplayed should be dispatched on the main queue. ")
    }
    
    func testNotWaitingForFullyDisplayed_AfterTracerTimesOut() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))

        let tracer = try fixture.getTracer()
        
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 10))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))

        // Timeout for tracer times out
        fixture.timerFactory.fire()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        sut.reportFullyDisplayed()
        
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 1_000)
        let ttidSpan = sut.initialDisplaySpan
        XCTAssertEqual(ttidSpan?.startTimestamp, Date(timeIntervalSince1970: 9))
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(ttidSpan?.status, .ok)
        
        XCTAssertNil(sut.fullDisplaySpan)
        XCTAssertNil(tracer.measurements["time_to_full_display"])
    }
    
    func testTracerWithAppStartData_notWaitingForFullDisplay() throws {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .cold, appStartTimestamp: Date(timeIntervalSince1970: 6), runtimeInitSystemTimestamp: 6_000_000_000)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 8))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportFullyDisplayed()
        fixture.displayLinkWrapper.normalFrame()
        
        tracer.finish()
        
        let ttidSpan = sut.initialDisplaySpan
        XCTAssertEqual(ttidSpan?.isFinished, true)
        XCTAssertEqual(ttidSpan?.startTimestamp, tracer.startTimestamp)
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 8))
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        XCTAssertNil(sut.fullDisplaySpan)
        XCTAssertNil(tracer.measurements["time_to_full_display"])
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }
    
    func testTracerWithAppStartData_waitingForFullDisplay() throws {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .cold, appStartTimestamp: Date(timeIntervalSince1970: 6), runtimeInitSystemTimestamp: 6_000_000_000)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 8))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportFullyDisplayed()
        fixture.displayLinkWrapper.normalFrame()
        
        tracer.finish()
        
        let ttidSpan = sut.initialDisplaySpan

        XCTAssertEqual(ttidSpan?.isFinished, true)
        XCTAssertEqual(ttidSpan?.startTimestamp, tracer.startTimestamp)
        XCTAssertEqual(ttidSpan?.timestamp, Date(timeIntervalSince1970: 8))
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        XCTAssertEqual(sut.fullDisplaySpan?.startTimestamp, ttidSpan?.startTimestamp)
        XCTAssertEqual(sut.fullDisplaySpan?.timestamp, Date(timeIntervalSince1970: 9))
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        XCTAssertEqual(Dynamic(self.fixture.framesTracker).listeners.count, 0)
    }

    func assertMeasurement(tracer: SentryTracer, name: String, duration: TimeInterval) {
        XCTAssertEqual(tracer.measurements[name]?.value, NSNumber(value: duration))
        XCTAssertEqual(tracer.measurements[name]?.unit?.unit, "millisecond")
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
