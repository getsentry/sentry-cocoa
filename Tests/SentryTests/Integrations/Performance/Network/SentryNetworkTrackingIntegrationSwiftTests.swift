@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        XCTAssertEqual(logMessages.count, 1)
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
        XCTAssertEqual(logMessages.count, 1)
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
        XCTAssertEqual(logMessages.count, 1)
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
        XCTAssertEqual(logMessages.count, 1)
    }

    func test_NetworkTrackingEnabled_IntegrationInstalled() {
        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableNetworkTracking = true

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isNetworkTrackingEnabled)
    }

    func test_OnlyBreadcrumbsEnabled_IntegrationInstalled() {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableNetworkBreadcrumbs = true

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isNetworkBreadcrumbEnabled)
    }

    func test_OnlyCaptureFailedRequestsEnabled_IntegrationInstalled() {
        let options = Options()
        options.tracesSampleRate = 0.0
        options.enableCaptureFailedRequests = true

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isCaptureFailedRequestsEnabled)
    }

    func test_GraphQLOperationTrackingEnabled() {
        let options = Options()
        options.tracesSampleRate = 1.0
        options.enableGraphQLOperationTracking = true

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        defer {
            sut?.uninstall()
        }

        XCTAssertNotNil(sut)
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isGraphQLOperationTrackingEnabled)
    }

    func test_Uninstall_DisablesNetworkTracker() {
        let options = Options()
        options.tracesSampleRate = 1.0

        let sut = SentryNetworkTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
        XCTAssertNotNil(sut)
        XCTAssertTrue(SentryNetworkTracker.sharedInstance.isNetworkTrackingEnabled)

        sut?.uninstall()

        XCTAssertFalse(SentryNetworkTracker.sharedInstance.isNetworkTrackingEnabled)
    }

    func test_IntegrationName() {
        XCTAssertEqual(SentryNetworkTrackingIntegration<SentryDependencyContainer>.name, "SentryNetworkTrackingIntegration")
    }
}
