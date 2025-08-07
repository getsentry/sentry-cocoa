@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentrySDKTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySDKTests")
    
    private class Fixture {
    
        @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
        let options: Options = {
            let options = Options.noIntegrations()
            options.dsn = SentrySDKTests.dsnAsString
            options.releaseName = "1.0.0"
            return options
        }()

        let event: Event
        let scope: Scope
        let client: TestClient
        let hub: SentryHub
        let error: Error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        @available(*, deprecated, message: "SentryUserFeedback is deprecated in favor of SentryFeedback.")
        let userFeedback: UserFeedback
        let feedback: SentryFeedback
        let currentDate = TestCurrentDateProvider()
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer: SentryWatchdogTerminationScopeObserver
        let scopePersistentStore: TestSentryScopePersistentStore
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        let scopeBlock: (Scope) -> Void = { scope in
            scope.setTag(value: "tag", key: "tag")
        }

        var scopeWithBlockApplied: Scope {
            let scope = self.scope
            scopeBlock(scope)
            return scope
        }

        let message = "message"
        let operation = "ui.load"
        let transactionName = "Load Main Screen"

        @available(*, deprecated, message: "This is marked deprecated as a workaround until we can remove SentryUserFeedback in favor of SentryFeedback. When SentryUserFeedback is removed, this deprecation annotation can be removed.")
        init() {
            SentryDependencyContainer.sharedInstance().dateProvider = currentDate

            event = Event()
            event.message = SentryMessage(formatted: message)

            scope = Scope()
            scope.setTag(value: "value", key: "key")

            client = TestClient(options: options)!
            hub = SentryHub(client: client, andScope: scope, andCrashWrapper: TestSentryCrashWrapper.sharedInstance(), andDispatchQueue: SentryDispatchQueueWrapper())

            userFeedback = UserFeedback(eventId: SentryId())
            userFeedback.comments = "Again really?"
            userFeedback.email = "tim@apple.com"
            userFeedback.name = "Tim Apple"

            feedback = SentryFeedback(message: "Again really?", name: "Tim Apple", email: "tim@apple.com")
            
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            options.dsn = SentrySDKTests.dsnAsString

            let fileManager = try! TestFileManager(options: options)
            let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 10, fileManager: fileManager)
            scopePersistentStore = try! XCTUnwrap(TestSentryScopePersistentStore(fileManager: fileManager))
            let attributesProcessor = SentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopePersistentStore: scopePersistentStore
            )
            observer = SentryWatchdogTerminationScopeObserver(breadcrumbProcessor: breadcrumbProcessor, attributesProcessor: attributesProcessor)
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        }
    }

    private var fixture: Fixture!

    @available(*, deprecated, message: "This is marked deprecated as a workaround (for the workaround deprecating the Fixture.init method) until we can remove SentryUserFeedback in favor of SentryFeedback. When SentryUserFeedback is removed, this deprecation annotation can be removed.")
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    override func tearDown() {
        super.tearDown()

        givenSdkWithHubButNoClient()

        if let autoSessionTracking = SentrySDKInternal.currentHub().installedIntegrations().first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }

        clearTestState()
    }

    // Repro for: https://github.com/getsentry/sentry-cocoa/issues/1325
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartWithZeroMaxBreadcrumbsOptionsDoesNotCrash() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.maxBreadcrumbs = 0
            options.setIntegrations([])
        }

        SentrySDK.addBreadcrumb(Breadcrumb(level: SentryLevel.warning, category: "test"))
        let breadcrumbs = Dynamic(SentrySDKInternal.currentHub().scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(0, breadcrumbs?.count)
    }
    
    func testStartWithConfigureOptions() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.debug = true
            options.diagnosticLevel = SentryLevel.debug
            options.attachStacktrace = true
        }

        let hub = SentrySDKInternal.currentHub()
        XCTAssertNotNil(hub)
        XCTAssertNotNil(hub.installedIntegrations)
        XCTAssertNotNil(hub.getClient()?.options)

        let options = hub.getClient()?.options
        XCTAssertNotNil(options)
        XCTAssertEqual(SentrySDKTests.dsnAsString, options?.dsn)
        XCTAssertEqual(SentryLevel.debug, options?.diagnosticLevel)
        XCTAssertEqual(true, options?.attachStacktrace)
        XCTAssertEqual(true, options?.enableAutoSessionTracking)

        var expectedIntegrations = [
            "SentryCrashIntegration",
            "SentryAutoBreadcrumbTrackingIntegration",
            "SentryAutoSessionTrackingIntegration",
            "SentryNetworkTrackingIntegration"
        ]
        if !SentryDependencyContainer.sharedInstance().crashWrapper.isBeingTraced() {
            expectedIntegrations.append("SentryANRTrackingIntegration")
        }

        assertIntegrationsInstalled(integrations: expectedIntegrations)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartStopBinaryImageCache() {
        SentrySDK.start { options in
            options.debug = true
            options.removeAllIntegrations()
        }

        XCTAssertNotNil(SentryDependencyContainer.sharedInstance().binaryImageCache.cache)
        XCTAssertGreaterThan(SentryDependencyContainer.sharedInstance().binaryImageCache.cache.count, 0)

        SentrySDK.close()

        XCTAssertNil(SentryDependencyContainer.sharedInstance().binaryImageCache.cache)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartWithConfigureOptions_NoDsn() throws {
        SentrySDK.start { options in
            options.debug = true
            options.removeAllIntegrations()
        }

        let options = SentrySDKInternal.currentHub().getClient()?.options
        XCTAssertNotNil(options, "Options should not be nil")
        XCTAssertNil(options?.parsedDsn)
        XCTAssertTrue(options?.enabled ?? false)
        XCTAssertEqual(true, options?.debug)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartWithConfigureOptions_WrongDsn() throws {
        SentrySDK.start { options in
            options.dsn = "wrong"
            options.removeAllIntegrations()
        }

        let options = SentrySDKInternal.currentHub().getClient()?.options
        XCTAssertNotNil(options, "Options should not be nil")
        XCTAssertTrue(options?.enabled ?? false)
        XCTAssertNil(options?.parsedDsn)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartWithConfigureOptions_BeforeSend() {
        var wasBeforeSendCalled = false
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.beforeSend = { event in
                wasBeforeSendCalled = true
                return event
            }
            options.removeAllIntegrations()
        }

        SentrySDK.capture(message: "")

        XCTAssertTrue(wasBeforeSendCalled, "beforeSend was not called.")
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testStartWithScope() {
        let scope = Scope()
        scope.setUser(User(userId: "me"))
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.maxBreadcrumbs = 123
            options.initialScope = { suggested in
                XCTAssertEqual(123, Dynamic(suggested).maxBreadcrumbs)
                return scope
            }
            options.removeAllIntegrations()
        }
        XCTAssertEqual("me", SentrySDKInternal.currentHub().scope.userObject?.userId)
        XCTAssertIdentical(scope, SentrySDKInternal.currentHub().scope)
    }

    func testDontStartInsideXcodePreview() {
        startprocessInfoWrapperForPreview()

        SentrySDK.start { options in
            options.debug = true
        }

        XCTAssertFalse(SentrySDK.isEnabled)
    }

    func testCrashedLastRun() {
        XCTAssertEqual(SentryDependencyContainer.sharedInstance().crashReporter.crashedLastLaunch, SentrySDK.crashedLastRun)
    }

    func testDetectedStartUpCrash_DefaultValue() {
        XCTAssertFalse(SentrySDK.detectedStartUpCrash)
    }
    
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testInstallIntegrations_NoIntegrations() {
        SentrySDK.start { options in
            options.removeAllIntegrations()
        }

        assertIntegrationsInstalled(integrations: [])
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testGlobalOptions() {
        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDKInternal.options, fixture.options)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testGlobalOptionsForPreview() {
        startprocessInfoWrapperForPreview()

        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDKInternal.options, fixture.options)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureEvent() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event)

        assertEventCaptured(expectedScope: fixture.scope)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureEventWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(event: fixture.event, scope: scope)
    
        assertEventCaptured(expectedScope: scope)
    }
       
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureEventWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertEventCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureEventWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertHubScopeNotChanged()
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureError() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error)

        assertErrorCaptured(expectedScope: fixture.scope)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureErrorWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(error: fixture.error, scope: scope)

        assertErrorCaptured(expectedScope: scope)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureErrorWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)

        assertErrorCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureErrorWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureException() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception)

        assertExceptionCaptured(expectedScope: fixture.scope)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureExceptionWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(exception: fixture.exception, scope: scope)

        assertExceptionCaptured(expectedScope: scope)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureExceptionWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)

        assertExceptionCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureExceptionWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureMessageWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)

        assertMessageCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testCaptureMessageWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }
    
    // MARK: - Logger Flush Tests
    
    func testFlush_CallsLoggerFlush() {
        fixture.client.options.experimental.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // Add a log to ensure there's something to flush
        SentrySDK.logger.info("Test log message")
        
        // Initially no logs should be sent (they're buffered)
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 0)
        
        // Flush the SDK
        SentrySDK.flush(timeout: 1.0)
        
        // Wait a bit for the log to be flushed
        let expectation = self.expectation(description: "Wait for async add.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
        
        // Now logs should be sent
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 1)
    }
    
    func testClose_CallsLoggerFlush() {
        fixture.client.options.experimental.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // Add a log to ensure there's something to flush
        SentrySDK.logger.info("Test log message")
        
        // Initially no logs should be sent (they're buffered)
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 0)
        
        // Close the SDK
        SentrySDK.close()
        
        // Wait a bit for the log to be added to the batcher
        let expectation = self.expectation(description: "Wait for flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
        
        // Now logs should be sent
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 1)
    }
    
    func testFlush_WithNoLogger_DoesNotCrash() {
        // Ensure no logger is set up
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // This should not crash
        SentrySDK.flush(timeout: 5.0)
    }
    
    func testClose_WithNoLogger_DoesNotCrash() {
        // Ensure no logger is set up
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // This should not crash
        SentrySDK.close()
    }
    
    func testFlush_WithLoggerButNoBatcher_DoesNotCrash() {
        fixture.client.options.experimental.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // This should not crash
        SentrySDK.flush(timeout: 5.0)
    }
    
    func testClose_WithLoggerButNoBatcher_DoesNotCrash() {
        fixture.client.options.experimental.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.client.options)
        
        // This should not crash
        SentrySDK.close()
    }
}

extension SentrySDKTests {
    private func assertEventCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
        XCTAssertEqual(fixture.event, client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(expectedScope, client.captureEventWithScopeInvocations.first?.scope)
    }
    
    private func assertErrorCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeInvocations.count)
        XCTAssertEqual(fixture.error.localizedDescription, client.captureErrorWithScopeInvocations.first?.error.localizedDescription)
        XCTAssertEqual(expectedScope, client.captureErrorWithScopeInvocations.first?.scope)
    }
    
    private func assertExceptionCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count)
        XCTAssertEqual(fixture.exception, client.captureExceptionWithScopeInvocations.first?.exception)
        XCTAssertEqual(expectedScope, client.captureExceptionWithScopeInvocations.first?.scope)
    }
    
    private func assertMessageCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureMessageWithScopeInvocations.count)
        XCTAssertEqual(fixture.message, client.captureMessageWithScopeInvocations.first?.message)
        XCTAssertEqual(expectedScope, client.captureMessageWithScopeInvocations.first?.scope)
    }
    
    private func assertHubScopeNotChanged() {
        let hubScope = SentrySDKInternal.currentHub().scope
        XCTAssertEqual(fixture.scope, hubScope)
    }
    
    private func startprocessInfoWrapperForPreview() {
        let testProcessInfoWrapper = TestSentryNSProcessInfoWrapper()
        testProcessInfoWrapper.overrides.environment = ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        SentryDependencyContainer.sharedInstance().processInfoWrapper = testProcessInfoWrapper
    }
    
    private func assertIntegrationsInstalled(integrations: [String]) {
        XCTAssertEqual(integrations.count, SentrySDKInternal.currentHub().installedIntegrations().count)
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDKInternal.currentHub().isIntegrationInstalled(integrationClass), "\(integration) not installed")
            } else {
                XCTFail("Integration \(integration) not installed.")
            }
        }
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    private func givenSdkWithHubButNoClient() {
        SentrySDKInternal.setCurrentHub(SentryHub(client: nil, andScope: nil))
        SentrySDKInternal.setStart(with: fixture.options)
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    private func givenSdkWithHub() {
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.options)
    }
}
