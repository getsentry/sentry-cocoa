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

        func simulateUpdate(status: SentryHingeStatus, angle: Double) {
            handler?(SentryHingeState(status: status, angle: angle))
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

    func testHingeUpdate_whenStatusChanges_shouldAddBreadcrumb() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, angle: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, angle: .pi)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let crumb = try XCTUnwrap(delegate.addCrumbInvocations.first)
        XCTAssertEqual(crumb.category, "device.event")
        XCTAssertEqual(crumb.type, "system")
        XCTAssertEqual(crumb.level, SentryLevel.info)
        let data = try XCTUnwrap(crumb.data)
        XCTAssertEqual(data["action"] as? String, "HINGE_STATE_CHANGE")
        XCTAssertEqual(data["status"] as? String, "fully_open")
        XCTAssertEqual(data["previous_status"] as? String, "closed")
        XCTAssertEqual(data["angle_degrees"] as? Int, 180)
    }

    func testHingeUpdate_whenPartiallyOpen_shouldRoundAngleToDegrees() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, angle: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, angle: .pi / 2 + 0.001)

        // -- Assert --
        let crumb = try XCTUnwrap(delegate.addCrumbInvocations.first)
        let data = try XCTUnwrap(crumb.data)
        XCTAssertEqual(data["status"] as? String, "partially_open")
        XCTAssertEqual(data["angle_degrees"] as? Int, 90)
    }

    func testHingeUpdate_whenFirstUpdate_shouldNotAddBreadcrumb() {
        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, angle: .pi)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenOnlyAngleChanges_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .partiallyOpen, angle: 1)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, angle: 1.5)
        hingeObserver.simulateUpdate(status: .partiallyOpen, angle: 2)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }

    func testHingeUpdate_whenStatusUnknown_shouldNotAddBreadcrumbOrResetStatus() throws {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, angle: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .unknown, angle: 0)
        hingeObserver.simulateUpdate(status: .fullyOpen, angle: .pi)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 1)
        let crumb = try XCTUnwrap(delegate.addCrumbInvocations.first)
        XCTAssertEqual(crumb.data?["previous_status"] as? String, "closed")
    }

    func testHingeUpdate_whenStatusChangesTwice_shouldAddBreadcrumbForEachChange() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, angle: 0)

        // -- Act --
        hingeObserver.simulateUpdate(status: .partiallyOpen, angle: 1)
        hingeObserver.simulateUpdate(status: .fullyOpen, angle: .pi)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 2)
        XCTAssertEqual(delegate.addCrumbInvocations.invocations.map { $0.data?["status"] as? String }, ["partially_open", "fully_open"])
    }

    func testHingeUpdate_afterStop_shouldNotAddBreadcrumb() {
        // -- Arrange --
        hingeObserver.simulateUpdate(status: .closed, angle: 0)
        sut.stop()

        // -- Act --
        hingeObserver.simulateUpdate(status: .fullyOpen, angle: .pi)

        // -- Assert --
        XCTAssertEqual(delegate.addCrumbInvocations.count, 0)
    }
}
#endif // os(iOS)
