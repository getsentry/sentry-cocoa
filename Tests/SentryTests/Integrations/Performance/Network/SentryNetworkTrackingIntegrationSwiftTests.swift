@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryNetworkTrackingIntegrationSwiftTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_SwizzlingDisabled_IntegrationNotInstalled() {
        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let options = Options()
        options.enableSwizzling = false
        options.tracesSampleRate = 1.0

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryNetworkTrackingIntegration because enableSwizzling is disabled.")
        }
        XCTAssertEqual(logMessages.count, 1, "Expected log not found")
    }

    func test_TracingDisabled_IntegrationNotInstalled() {
        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryNetworkTrackingIntegration because isTracingEnabled is disabled.")
        }
        XCTAssertEqual(logMessages.count, 1, "Expected log not found")
    }

    func test_AutoPerformanceTracingDisabled_IntegrationNotInstalled() {
        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableAutoPerformanceTracing = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryNetworkTrackingIntegration because enableAutoPerformanceTracing is disabled.")
        }
        XCTAssertEqual(logMessages.count, 1, "Expected log not found")
    }

    func test_NetworkTrackingDisabled_IntegrationNotInstalled() {
        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        SentrySDKLog.configureLog(true, diagnosticLevel: .debug)

        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableNetworkTracking = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        XCTAssertNil(sut)
        let logMessages = logOutput.loggedMessages.filter {
            $0.contains("Not going to enable SentryNetworkTrackingIntegration because enableNetworkTracking is disabled.")
        }
        XCTAssertEqual(logMessages.count, 1, "Expected log not found")
    }

    func test_NetworkTrackingEnabled_IntegrationInstalled() throws {
        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableNetworkTracking = true

        let sut = try XCTUnwrap(SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer {
            sut.uninstall()
        }

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkTrackingEnabled)
    }

    func test_OnlyBreadcrumbsEnabled_IntegrationInstalled() throws {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableNetworkBreadcrumbs = true

        let sut = try XCTUnwrap(SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer {
            sut.uninstall()
        }

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkBreadcrumbEnabled)
    }

    func test_OnlyCaptureFailedRequestsEnabled_IntegrationInstalled() throws {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableCaptureFailedRequests = true

        let sut = try XCTUnwrap(SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer {
            sut.uninstall()
        }
        
        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isCaptureFailedRequestsEnabled)
    }

    func test_GraphQLOperationTrackingEnabled() throws {
        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableGraphQLOperationTracking = true

        let sut = try XCTUnwrap(SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        defer {
            sut.uninstall()
        }

        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isGraphQLOperationTrackingEnabled)
    }

    func test_Uninstall_DisablesNetworkTracker() throws {
        let options = Options()
        options.tracesSampleRate = 1.0

        let sut = try XCTUnwrap(SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        XCTAssertTrue(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkTrackingEnabled)

        sut.uninstall()

        XCTAssertFalse(SentryDependencyContainer.sharedInstance().networkTracker.isNetworkTrackingEnabled)
    }

    func testNetworkTrackerProxy_whenTargetChanges_shouldForwardToLatestTarget() {
        let sut = SentryNetworkTrackerProxy()
        let firstTracker = TestNetworkTracker()
        let secondTracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        sut.setTarget(firstTracker)
        sut.target?.urlSessionTaskResume(task)
        sut.setTarget(secondTracker)
        sut.target?.urlSessionTaskResume(task)

        XCTAssertEqual(firstTracker.resumeInvocations, 1)
        XCTAssertEqual(secondTracker.resumeInvocations, 1)
    }

    func testNetworkTrackerProxy_shouldNotRetainTarget() {
        let sut = SentryNetworkTrackerProxy()
        weak var weakTracker: TestNetworkTracker?

        autoreleasepool {
            let tracker = TestNetworkTracker()
            weakTracker = tracker
            sut.setTarget(tracker)
        }

        XCTAssertNil(weakTracker)
    }

    func testNetworkTrackerProxy_whenRemovingStaleTarget_shouldKeepLatestTarget() {
        let sut = SentryNetworkTrackerProxy()
        let firstTracker = TestNetworkTracker()
        let secondTracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        sut.setTarget(firstTracker)
        sut.setTarget(secondTracker)
        sut.removeTarget(firstTracker)
        sut.target?.urlSessionTaskResume(task)

        XCTAssertEqual(firstTracker.resumeInvocations, 0)
        XCTAssertEqual(secondTracker.resumeInvocations, 1)
    }

    func testNetworkTrackerProxy_whenRemovingCurrentTarget_shouldStopForwarding() {
        let sut = SentryNetworkTrackerProxy()
        let tracker = TestNetworkTracker()
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)

        sut.setTarget(tracker)
        sut.removeTarget(tracker)
        sut.target?.urlSessionTaskResume(task)

        XCTAssertEqual(tracker.resumeInvocations, 0)
    }

    func test_IntegrationName() {
        XCTAssertEqual(SentryNetworkTrackingIntegration<SentryDependencyContainer>.name, "SentryNetworkTrackingIntegration")
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

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    func captureResponseDetails(_ data: Data, response: URLResponse, request requestURL: URL, task: URLSessionTask) {}
#endif
}
