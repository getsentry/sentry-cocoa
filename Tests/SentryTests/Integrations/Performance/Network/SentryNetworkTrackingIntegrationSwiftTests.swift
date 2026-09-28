@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryNetworkTrackingIntegrationSwiftTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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

#if compiler(>=6.1)
    func testNewLoaderSwizzling_whenDefault_shouldNotWrapCompletionHandlers() throws {
        // -- Arrange --
        guard #available(macOS 15.4, iOS 18.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *) else {
            throw XCTSkip("The selected OS does not support choosing the URLSession HTTP loader.")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.usesClassicLoadingMode = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let options = Options()
        let integration = try XCTUnwrap(SentryNetworkTrackingIntegration(
            with: options,
            dependencies: SentryDependencyContainer.sharedInstance()
        ))
        defer { integration.uninstall() }
        let url = try XCTUnwrap(URL(string: "https://request.invalid/"))

        // -- Act --
        let tasks: [URLSessionTask] = [
            session.dataTask(with: url) { _, _, _ in },
            session.dataTask(with: URLRequest(url: url)) { _, _, _ in },
            session.downloadTask(with: url) { _, _, _ in },
            session.uploadTask(with: URLRequest(url: url), from: Data()) { _, _, _ in }
        ]
        defer { tasks.forEach { $0.cancel() } }

        // -- Assert --
        for task in tasks {
            XCTAssertFalse(task.usesNewLoaderCompletionHandler)
        }
    }

    func testResume_whenNewLoaderExistsBeforeSDKStart_shouldTrackAcrossRestart() throws {
        // -- Arrange --
        guard #available(macOS 15.4, iOS 18.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *) else {
            throw XCTSkip("The selected OS does not support choosing the URLSession HTTP loader.")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.usesClassicLoadingMode = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let url = try XCTUnwrap(URL(string: "https://request.invalid/"))
        let probe = session.dataTask(with: url)
        defer { probe.cancel() }

        let oldDebug = SentrySDKLog.isDebug
        let oldLevel = SentrySDKLog.diagnosticLevel
        let oldOutput = SentrySDKLog.getLogOutput()
        defer {
            SentrySDK.close()
            SentrySDKLogSupport.configure(oldDebug, diagnosticLevel: oldLevel)
            SentrySDKLog.setOutput(oldOutput)
        }
        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: #function)
        options.removeAllIntegrations()
        options.enableAutoPerformanceTracing = true
        options.enableNetworkTracking = true
        options.tracesSampleRate = 1.0
        options.debug = true
        options.diagnosticLevel = .error
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        options.sessionReplay.networkDetailAllowUrls = ["request.invalid"]
#endif

        for enabled in [false, true, true, false, true] {
            // -- Act --
            options.enabled = true
            options.experimental.enableNewURLLoaderSwizzling = enabled
            SentrySDK.start(options: options)
            let transaction = try XCTUnwrap(SentrySDK.startTransaction(
                name: "New loader before SDK start",
                operation: "test",
                bindToScope: true
            ) as? SentryTracer)
            let completed = expectation(description: "Tasks completed")
            completed.expectedFulfillmentCount = 4
            let tasks: [URLSessionTask] = [
                session.dataTask(with: url) { _, _, _ in completed.fulfill() },
                session.dataTask(with: URLRequest(url: url)) { _, _, _ in completed.fulfill() },
                session.downloadTask(with: url) { _, _, _ in completed.fulfill() },
                session.uploadTask(with: URLRequest(url: url), from: Data()) { _, _, _ in completed.fulfill() }
            ]
            for task in tasks {
#if !os(watchOS)
                XCTAssertEqual(task.usesNewLoaderCompletionHandler, enabled)
#endif
                task.resume()
                task.cancel()
            }
            wait(for: [completed], timeout: 5)

            // -- Assert --
            XCTAssertFalse(logOutput.loggedMessages.contains { $0.contains("Swizzle receiver mismatch") })
            if enabled {
                XCTAssertEqual(transaction.children.count, 4)
                for span in transaction.children {
                    XCTAssertEqual(span.operation, "http.client")
                    XCTAssertTrue(span.isFinished)
                }
            }
            SentrySDK.close()
        }
    }
#endif

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
