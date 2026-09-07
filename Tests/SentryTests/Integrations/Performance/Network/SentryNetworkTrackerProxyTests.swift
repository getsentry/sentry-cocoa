@_spi(Private) @testable import Sentry
import XCTest

final class SentryNetworkTrackerProxyTests: XCTestCase {

    func testTarget_whenNotSet_shouldBeNil() {
        // -- Arrange --
        let sut = SentryNetworkTrackerProxy()

        // -- Act --
        let target = sut.target

        // -- Assert --
        XCTAssertNil(target)
    }

    func testTarget_whenTargetChanges_shouldForwardToLatestTarget() {
        // -- Arrange --
        let sut = SentryNetworkTrackerProxy()
        let firstTracker = TestNetworkTracker()
        let secondTracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        // -- Act --
        sut.setTarget(firstTracker)
        sut.target?.urlSessionTaskResume(task)
        sut.setTarget(secondTracker)
        sut.target?.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(firstTracker.resumeInvocations, 1)
        XCTAssertEqual(secondTracker.resumeInvocations, 1)
    }

    func testTarget_shouldNotRetainTarget() {
        // -- Arrange --
        let sut = SentryNetworkTrackerProxy()
        weak var weakTracker: TestNetworkTracker?

        // -- Act --
        autoreleasepool {
            let tracker = TestNetworkTracker()
            weakTracker = tracker
            sut.setTarget(tracker)
        }

        // -- Assert --
        XCTAssertNil(weakTracker)
        XCTAssertNil(sut.target)
    }

    func testRemoveTarget_whenRemovingStaleTarget_shouldKeepLatestTarget() {
        // -- Arrange --
        let sut = SentryNetworkTrackerProxy()
        let firstTracker = TestNetworkTracker()
        let secondTracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        sut.setTarget(firstTracker)
        sut.setTarget(secondTracker)

        // -- Act --
        sut.removeTarget(firstTracker)
        sut.target?.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(firstTracker.resumeInvocations, 0)
        XCTAssertEqual(secondTracker.resumeInvocations, 1)
    }

    func testRemoveTarget_whenRemovingCurrentTarget_shouldStopForwarding() {
        // -- Arrange --
        let sut = SentryNetworkTrackerProxy()
        let tracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        sut.setTarget(tracker)

        // -- Act --
        sut.removeTarget(tracker)
        sut.target?.urlSessionTaskResume(task)

        // -- Assert --
        XCTAssertEqual(tracker.resumeInvocations, 0)
        XCTAssertNil(sut.target)
    }
}

private final class TestNetworkTracker: SentryNetworkTrackerProtocol {
    private(set) var resumeInvocations = 0

    func enableNetworkTracking() {}
    func enableNetworkBreadcrumbs() {}
    func enableCaptureFailedRequests() {}
    func enableGraphQLOperationTracking() {}
    func disable() {}

    var isNetworkTrackingEnabled: Bool { false }
    var isNetworkBreadcrumbEnabled: Bool { false }
    var isCaptureFailedRequestsEnabled: Bool { false }
    var isGraphQLOperationTrackingEnabled: Bool { false }

    func urlSessionTaskResume(_ sessionTask: URLSessionTask) {
        resumeInvocations += 1
    }

    func urlSessionTask(_ sessionTask: URLSessionTask, setState newState: URLSessionTask.State) {}

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func captureResponseDetails(_ data: Data, response: URLResponse, request requestURL: URL, task: URLSessionTask) {}
#endif
}
