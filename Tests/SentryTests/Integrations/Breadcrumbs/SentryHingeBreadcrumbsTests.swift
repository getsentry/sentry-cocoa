@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS)
class SentryHingeBreadcrumbsTests: XCTestCase {

    private final class TestHingeObserver: SentryHingeObserving {
        private var handler: ((SentryHingeState) -> Void)?
        var currentState: SentryHingeState?
        var startInvocations = 0
        var stopInvocations = 0

        var isRunning: Bool { handler != nil }

        func start(handler: @escaping (SentryHingeState) -> Void) {
            self.handler = handler
            startInvocations += 1
        }

        func stop() {
            handler = nil
            stopInvocations += 1
        }

        func simulateUpdate(status: SentryHingeStatus, degrees: Double) {
            let state = SentryHingeState(status: status, angle: degrees * .pi / 180)
            currentState = state
            handler?(state)
        }
    }

    private var hingeObserver: TestHingeObserver!
    private var delegate: SentryBreadcrumbTestDelegate!
    private var sut: SentryHingeBreadcrumbs!

    override func setUp() {
        super.setUp()
        hingeObserver = TestHingeObserver()
        delegate = SentryBreadcrumbTestDelegate()
        sut = SentryHingeBreadcrumbs(hingeObserver: hingeObserver)
        sut.start(with: delegate)
    }

    override func tearDown() {
        sut.stop()
        super.tearDown()
    }

    func testStart_shouldStartHingeObserver() {
        // -- Assert --
        XCTAssertEqual(hingeObserver.startInvocations, 1)
        XCTAssertTrue(hingeObserver.isRunning)
    }

    func testStop_shouldStopHingeObserver() {
        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertEqual(hingeObserver.stopInvocations, 1)
        XCTAssertFalse(hingeObserver.isRunning)
    }

    func testHingeUpdate_whenOpeningPastThreshold_shouldAddOpeningBreadcrumb() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let crumb = try XCTUnwrap(delegate.addCrumbInvocations.first)
        XCTAssertEqual(crumb.category, "device.event")
        XCTAssertEqual(crumb.type, "system")
        XCTAssertEqual(crumb.level, SentryLevel.info)
        let data = try XCTUnwrap(crumb.data)
        XCTAssertEqual(data["action"] as? String, "HINGE_STATE_CHANGE")
        XCTAssertEqual(data["direction"] as? String, "opening")
        XCTAssertEqual(data["status"] as? String, "fully_open")
        XCTAssertEqual(data["previous_status"] as? String, "closed")
        XCTAssertNil(data["angle_degrees"])
    }

    func testHingeUpdate_whenClosingPastThreshold_shouldAddClosingBreadcrumb() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 100)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let data = try XCTUnwrap(delegate.addCrumbInvocations.first?.data)
        XCTAssertEqual(data["direction"] as? String, "closing")
        XCTAssertEqual(data["status"] as? String, "partially_open")
        XCTAssertEqual(data["previous_status"] as? String, "fully_open")
    }

    func testHingeUpdate_whenMovedExactlyThreshold_shouldAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 45)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
    }

    func testHingeUpdate_whenMovedLessThanThreshold_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 20)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 44)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenMovedInSmallSteps_shouldMeasureFromLastBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 30)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 60)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 90)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 120)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 2)
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["direction"] as? String }, ["opening", "opening"])
    }

    func testHingeUpdate_whenFullyOpenBelowThreshold_shouldAddOpeningBreadcrumb() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 170)

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let data = try XCTUnwrap(delegate.addCrumbInvocations.first?.data)
        XCTAssertEqual(data["direction"] as? String, "opening")
        XCTAssertEqual(data["status"] as? String, "fully_open")
        XCTAssertEqual(data["previous_status"] as? String, "partially_open")
    }

    func testHingeUpdate_whenClosedBelowThreshold_shouldAddClosingBreadcrumb() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 10)

        // -- Act --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let data = try XCTUnwrap(delegate.addCrumbInvocations.first?.data)
        XCTAssertEqual(data["direction"] as? String, "closing")
        XCTAssertEqual(data["status"] as? String, "closed")
        XCTAssertEqual(data["previous_status"] as? String, "partially_open")
    }

    func testHingeUpdate_whenEndPositionReportedAgain_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 170)
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 179)
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
    }

    func testHingeUpdate_whenPartiallyOpenBelowThreshold_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 170)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenFullSweepInSmallSteps_shouldEndWithEndPosition() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        for degrees in stride(from: 10, through: 170, by: 10) {
            hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: Double(degrees))
        }
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["status"] as? String }, ["partially_open", "partially_open", "partially_open", "fully_open"])
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["direction"] as? String }, ["opening", "opening", "opening", "opening"])
    }

    func testHingeUpdate_whenWobblingBelowThreshold_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 90)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 110)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 70)
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 100)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenDirectionReverses_shouldAddBreadcrumbForEachDirection() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, degrees: 90)
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 2)
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["direction"] as? String }, ["opening", "closing"])
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["status"] as? String }, ["partially_open", "closed"])
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["previous_status"] as? String }, ["closed", "partially_open"])
    }

    func testHingeUpdate_whenClosedReportedAgainWithLargerAngleChange_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)
        // The hinge reports the closed status before the angle settles.
        hingeObserver.simulateUpdate(status: .closed, degrees: 60)

        // -- Act --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["status"] as? String }, ["closed"])
    }

    func testHingeUpdate_whenFullyOpenReportedAgainWithLargerAngleChange_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 120)

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["status"] as? String }, ["fully_open"])
    }

    func testHingeUpdate_whenFirstUpdate_shouldNotAddBreadcrumb() {
        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenStatusUnknown_shouldNotAddBreadcrumbOrResetState() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .unknown, degrees: 180)
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let data = try XCTUnwrap(delegate.addCrumbInvocations.first?.data)
        XCTAssertEqual(data["direction"] as? String, "opening")
        XCTAssertEqual(data["previous_status"] as? String, "closed")
    }

    func testHingeUpdate_afterStop_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, degrees: 0)
        sut.stop()

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, degrees: 180)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }
}
#endif // os(iOS)
