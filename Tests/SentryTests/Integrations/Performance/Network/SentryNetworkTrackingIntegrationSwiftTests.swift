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

    func testCancel_whenRequestIsInFlight_shouldReachProtocolAndCompletion() throws {
        // -- Arrange --
        let requestStarted = expectation(description: "Request started")
        let requestCancelled = expectation(description: "Request cancelled")
        let requestCompleted = expectation(description: "Request completed")
        CancellationObservingURLProtocol.callbacks.withLock {
            $0 = .init(
                requestStarted: { requestStarted.fulfill() },
                requestCancelled: { requestCancelled.fulfill() }
            )
        }
        defer {
            CancellationObservingURLProtocol.callbacks.withLock { $0 = nil }
        }

        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: #function)
        options.tracesSampleRate = 1.0
        options.enableNetworkTracking = true
        SentrySDK.start(options: options)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CancellationObservingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try XCTUnwrap(URL(string: "https://www.domain.com/api"))
        let task = session.dataTask(with: url) { _, _, error in
            let urlError = error as? URLError
            XCTAssertEqual(urlError?.code, .cancelled)
            requestCompleted.fulfill()
        }

        // -- Act --
        task.resume()
        wait(for: [requestStarted], timeout: 1)
        task.cancel()

        // -- Assert --
        wait(for: [requestCancelled, requestCompleted], timeout: 1)
    }

    func test_IntegrationName() {
        XCTAssertEqual(SentryNetworkTrackingIntegration<SentryDependencyContainer>.name, "SentryNetworkTrackingIntegration")
    }
}

private final class CancellationObservingURLProtocol: URLProtocol {
    struct Callbacks {
        let requestStarted: () -> Void
        let requestCancelled: () -> Void
    }

    static let callbacks = SentryMutex<Callbacks?>(nil)

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        CancellationObservingURLProtocol.callbacks.withLock { $0?.requestStarted() }
    }

    override func stopLoading() {
        CancellationObservingURLProtocol.callbacks.withLock { $0?.requestCancelled() }
    }
}
