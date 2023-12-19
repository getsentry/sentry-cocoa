import Foundation
import Nimble
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
            framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: dateProvider, keepDelayedFramesDuration: 0)
            SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
            framesTracker.start()
        }

        func getSut(for controller: UIViewController, waitForFullDisplay: Bool) -> SentryTimeToDisplayTracker {
            return SentryTimeToDisplayTracker(for: controller, waitForFullDisplay: waitForFullDisplay)
        }
        
        func getTracer() throws -> SentryTracer {
            let options = Options()
            let hub = TestHub(client: SentryClient(options: options, fileManager: try TestFileManager(options: options), deleteOldEnvelopeItems: false), andScope: nil)
            return SentryTracer(transactionContext: TransactionContext(operation: "ui.load"), hub: hub, configuration: SentryTracerConfiguration(block: {
                $0.waitForChildren = true
                $0.timerFactory = self.timerFactory
                $0.dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
            }))
        }
    }

    private lazy var fixture = Fixture()

    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.dateProvider
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
        expect(tracer.children.count) == 1
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 1

        let ttidSpan = try XCTUnwrap(tracer.children.first, "Expected a TTID span")
        expect(ttidSpan.startTimestamp) == fixture.dateProvider.date()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()
        expect(ttidSpan.timestamp) == nil
        expect(ttidSpan.isFinished) == false
        
        fixture.displayLinkWrapper.normalFrame()
        tracer.finish()

        expect(ttidSpan.timestamp) == fixture.dateProvider.date()
        expect(ttidSpan.isFinished) == true
        expect(ttidSpan.spanDescription) == "UIViewController initial display"
        expect(ttidSpan.operation) == SentrySpanOperationUILoadInitialDisplay
        expect(ttidSpan.origin) == "auto.ui.time_to_display"

        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
    }

    func testReportInitialDisplay_waitForFullDisplay() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 7))

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)
        expect(tracer.children.count) == 2

        let ttidSpan = sut.initialDisplaySpan
        expect(ttidSpan?.startTimestamp) == fixture.dateProvider.date()

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        expect(ttidSpan?.isFinished) == true
        expect(ttidSpan?.timestamp) == Date(timeIntervalSince1970: 9)
        expect(tracer.measurements["time_to_initial_display"]) == nil

        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 11))
        sut.reportFullyDisplayed()
        
        // TTFD not reported yet cause we wait for the next frame
        expect(sut.fullDisplaySpan?.startTimestamp) == ttidSpan?.startTimestamp
        expect(sut.fullDisplaySpan?.timestamp) == nil
        expect(tracer.measurements["time_to_full_display"]) == nil
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 1
    }

    func testReportFullDisplay_notWaitingForFullDisplay() throws {
        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: false)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        sut.reportInitialDisplay()
        fixture.displayLinkWrapper.normalFrame()

        sut.reportFullyDisplayed()

        expect(sut.fullDisplaySpan) == nil
        expect(tracer.children.count) == 1
        expect(tracer.measurements["time_to_full_display"]) == nil
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
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

        expect(sut.fullDisplaySpan) != nil
        expect(sut.fullDisplaySpan?.startTimestamp) == Date(timeIntervalSince1970: 9)
        expect(sut.fullDisplaySpan?.timestamp) == Date(timeIntervalSince1970: 12)
        expect(sut.fullDisplaySpan?.status) == .ok

        expect(sut.fullDisplaySpan?.spanDescription) == "UIViewController full display"
        expect(sut.fullDisplaySpan?.operation) == SentrySpanOperationUILoadFullDisplay
        expect(sut.fullDisplaySpan?.origin) == "manual.ui.time_to_display"
        
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
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

        expect(sut.fullDisplaySpan?.isFinished) == false
        expect(sut.initialDisplaySpan?.isFinished) == false
        
        sut.reportInitialDisplay()
        
        expect(sut.fullDisplaySpan?.isFinished) == false
        expect(sut.initialDisplaySpan?.isFinished) == false
        
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 12))
        fixture.displayLinkWrapper.normalFrame()
        tracer.finish()
        
        expect(sut.initialDisplaySpan?.isFinished) == true
        expect(sut.initialDisplaySpan?.timestamp) == Date(timeIntervalSince1970: 12)
        expect(sut.initialDisplaySpan?.status) == .ok
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 3_000)
        
        expect(sut.fullDisplaySpan?.isFinished) == true
        expect(sut.fullDisplaySpan?.timestamp) == Date(timeIntervalSince1970: 12)
        expect(sut.fullDisplaySpan?.status) == .ok
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
    }

    func testCheckInitialTime() throws {
        fixture.dateProvider.setDate(date: Date(timeIntervalSince1970: 9))
        fixture.dateProvider.driftTimeForEveryRead = true

        let sut = fixture.getSut(for: UIViewController(), waitForFullDisplay: true)
        let tracer = try fixture.getTracer()

        sut.start(for: tracer)

        expect(sut.fullDisplaySpan) != nil
        expect(sut.fullDisplaySpan?.startTimestamp) == tracer.startTimestamp
        expect(sut.initialDisplaySpan?.startTimestamp) == tracer.startTimestamp
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
        expect(ttidSpan?.startTimestamp) == Date(timeIntervalSince1970: 9)
        expect(ttidSpan?.timestamp) == Date(timeIntervalSince1970: 10)
        expect(ttidSpan?.status) == .ok
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 1_000)
        
        let ttfdSpan = sut.fullDisplaySpan
        expect(ttfdSpan?.startTimestamp) == ttidSpan?.startTimestamp
        expect(ttfdSpan?.timestamp) == ttidSpan?.timestamp
        expect(ttfdSpan?.status) == .deadlineExceeded
        expect(ttfdSpan?.spanDescription) == "UIViewController full display - Deadline Exceeded"
        expect(ttfdSpan?.operation) == SentrySpanOperationUILoadFullDisplay
        expect(ttfdSpan?.origin) == "manual.ui.time_to_display"
        
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 1_000)
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
        expect(ttidSpan?.startTimestamp) == Date(timeIntervalSince1970: 9)
        expect(ttidSpan?.timestamp) == Date(timeIntervalSince1970: 10)
        expect(ttidSpan?.status) == .ok
        
        expect(sut.fullDisplaySpan) == nil
        expect(tracer.measurements["time_to_full_display"]) == nil
    }
    
    func testTracerWithAppStartData_notWaitingForFullDisplay() throws {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .cold, appStartTimestamp: Date(timeIntervalSince1970: 6))
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
        expect(ttidSpan?.isFinished) == true
        expect(ttidSpan?.startTimestamp) == tracer.startTimestamp
        expect(ttidSpan?.timestamp) == Date(timeIntervalSince1970: 8)
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        expect(sut.fullDisplaySpan) == nil
        expect(tracer.measurements["time_to_full_display"]) == nil
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
    }
    
    func testTracerWithAppStartData_waitingForFullDisplay() throws {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .cold, appStartTimestamp: Date(timeIntervalSince1970: 6))
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

        expect(ttidSpan?.isFinished) == true
        expect(ttidSpan?.startTimestamp) == tracer.startTimestamp
        expect(ttidSpan?.timestamp) == Date(timeIntervalSince1970: 8)
        assertMeasurement(tracer: tracer, name: "time_to_initial_display", duration: 2_000)

        expect(sut.fullDisplaySpan?.startTimestamp) == ttidSpan?.startTimestamp
        expect(sut.fullDisplaySpan?.timestamp) == Date(timeIntervalSince1970: 9)
        assertMeasurement(tracer: tracer, name: "time_to_full_display", duration: 3_000)
        
        expect(Dynamic(self.fixture.framesTracker).listeners.count) == 0
    }

    func assertMeasurement(tracer: SentryTracer, name: String, duration: TimeInterval) {
        expect(tracer.measurements[name]?.value) == NSNumber(value: duration)
        expect(tracer.measurements[name]?.unit?.unit) == "millisecond"
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
