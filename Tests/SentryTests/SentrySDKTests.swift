@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentrySDKTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySDKTests")
    
    private class Fixture {
    
        let options: Options = {
            let options = Options.noIntegrations()
            options.dsn = SentrySDKTests.dsnAsString
            options.releaseName = "1.0.0"
            options.enableAutoSessionTracking = false
            return options
        }()

        let event: Event
        let scope: Scope
        let client: TestClient
        let hub: SentryHubInternal
        let error: Error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let feedback: SentryFeedback

        let currentDate = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
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

        init() throws {
            SentryDependencyContainer.sharedInstance().dateProvider = currentDate

            event = Event()
            event.message = SentryMessage(formatted: message)

            scope = Scope()
            scope.setTag(value: "value", key: "key")

            client = TestClient(options: options)!
            hub = SentryHubInternal(client: client, andScope: scope, andCrashWrapper: TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo), andDispatchQueue: SentryDispatchQueueWrapper())

            feedback = SentryFeedback(message: "Again really?", name: "Tim Apple", email: "tim@apple.com")
            
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            options.dsn = SentrySDKTests.dsnAsString

            let fileManager = try XCTUnwrap(TestFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueueWrapper
            ))
            let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 10, fileManager: fileManager)
            scopePersistentStore = try XCTUnwrap(TestSentryScopePersistentStore(fileManager: fileManager))
            let attributesProcessor = SentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopePersistentStore: scopePersistentStore
            )
            observer = SentryWatchdogTerminationScopeObserver(breadcrumbProcessor: breadcrumbProcessor, attributesProcessor: attributesProcessor)
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
    }
    
    override func tearDown() {
        super.tearDown()

        givenSdkWithHubButNoClient()

        clearTestState()
    }

    // Repro for: https://github.com/getsentry/sentry-cocoa/issues/1325
    func testStartWithZeroMaxBreadcrumbsOptionsDoesNotCrash() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.maxBreadcrumbs = 0
            options.removeAllIntegrations()
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
            "SentryMetricsIntegration",
            "SentryNetworkTrackingIntegration"
        ]
        if !SentryDependencyContainer.sharedInstance().crashWrapper.isBeingTraced {
            expectedIntegrations.append("SentryANRTrackingIntegration")
        }
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        expectedIntegrations.append("SentryFramesTrackingIntegration")
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        assertIntegrationsInstalled(integrations: expectedIntegrations)
    }

    func testStartStopBinaryImageCache() throws {
        SentrySDK.start { options in
            options.debug = true
            options.removeAllIntegrations()
        }

        XCTAssertNotNil(SentryDependencyContainer.sharedInstance().binaryImageCache.cache)
        let cache = try XCTUnwrap(SentryDependencyContainer.sharedInstance().binaryImageCache.cache)
        XCTAssertGreaterThan(cache.count, 0)

        SentrySDK.close()

        XCTAssertNil(SentryDependencyContainer.sharedInstance().binaryImageCache.cache)
    }

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
    
    func testInstallIntegrations_NoIntegrations() {
        SentrySDK.start { options in
            options.removeAllIntegrations()
        }

        assertIntegrationsInstalled(integrations: [])
    }

    func testGlobalOptions() {
        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDK.startOption, fixture.options)
    }

    func testGlobalOptionsForPreview() {
        startprocessInfoWrapperForPreview()

        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDK.startOption, fixture.options)
    }

    func testCaptureEvent() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event)

        assertEventCaptured(expectedScope: fixture.scope)
    }

    func testCaptureEventWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(event: fixture.event, scope: scope)
    
        assertEventCaptured(expectedScope: scope)
    }
       
    func testCaptureEventWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertEventCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    func testCaptureEventWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event, block: fixture.scopeBlock)
    
        assertHubScopeNotChanged()
    }

    func testCaptureError() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error)

        assertErrorCaptured(expectedScope: fixture.scope)
    }

    func testCaptureErrorWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(error: fixture.error, scope: scope)

        assertErrorCaptured(expectedScope: scope)
    }

    func testCaptureErrorWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)

        assertErrorCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    func testCaptureErrorWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }

    func testCaptureException() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception)

        assertExceptionCaptured(expectedScope: fixture.scope)
    }

    func testCaptureExceptionWithScope() {
        givenSdkWithHub()

        let scope = Scope()
        SentrySDK.capture(exception: fixture.exception, scope: scope)

        assertExceptionCaptured(expectedScope: scope)
    }

    func testCaptureExceptionWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)

        assertExceptionCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    func testCaptureExceptionWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }

    func testCaptureMessageWithScopeBlock_ScopePassedToHub() {
        givenSdkWithHub()

        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)

        assertMessageCaptured(expectedScope: fixture.scopeWithBlockApplied)
    }

    func testCaptureMessageWithScopeBlock_CreatesNewScope() {
        givenSdkWithHub()

        SentrySDK.capture(message: fixture.message, block: fixture.scopeBlock)

        assertHubScopeNotChanged()
    }
    
    /// When events don't have debug meta the backend can't symbolicate the stack trace of events.
    /// This is a regression test for https://github.com/getsentry/sentry-cocoa/issues/5334
    func testCaptureNonFatalEvent_HasDebugMeta() throws {

        var eventInBeforeSend: Event?

        // Arrange
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "testCaptureNonFatalEvent_HasDebugMeta")
            options.beforeSend = { event in
                eventInBeforeSend = event
                return nil
            }
        }
        // Act
        SentrySDK.capture(message: "Test message")

        // Assert

        let event = try XCTUnwrap(eventInBeforeSend)

        let debugMetas = try XCTUnwrap(event.debugMeta, "Expected event to have debug meta but got nil")
        // During local testing we got 6 debug metas, but to avoid flakiness in CI we only check for 3.
        XCTAssertGreaterThanOrEqual(debugMetas.count, 3, "Expected debug meta to have at least 3 items, but got \(debugMetas.count)")

        for debugMeta in debugMetas {
            XCTAssertEqual(debugMeta.type, "macho")
            XCTAssertNotNil(debugMeta.debugID)
            XCTAssertNotNil(debugMeta.imageAddress)
            XCTAssertNotNil(debugMeta.imageSize)
        }
    }

    // MARK: - Logger Flush Tests
    
    func testFlush_CallsLoggerCaptureLogs() {
        fixture.client.options.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDK.setStart(with: fixture.client.options)
        
        // Add a log to ensure there's something to flush
        SentrySDK.logger.info("Test log message")
        
        // Verify the log was captured
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        XCTAssertEqual(fixture.client.captureLogInvocations.first?.log.body, "Test log message")
        
        // Flush the SDK - this should trigger the log batcher to flush
        SentrySDK.flush(timeout: 1.0)
        
        // The log should still be captured (flush doesn't clear the invocations)
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
    }
    
    func testClose_CallsLoggerCaptureLogs() {
        fixture.client.options.enableLogs = true
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDK.setStart(with: fixture.client.options)
        
        // Add a log to ensure there's something to flush
        SentrySDK.logger.info("Test log message")
        
        // Verify the log was captured
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        
        // Close the SDK
        SentrySDK.close()
        
        // The log should still be captured
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
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
        let testProcessInfoWrapper = MockSentryProcessInfo()
        testProcessInfoWrapper.overrides.environment = ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        SentryDependencyContainer.sharedInstance().processInfoWrapper = testProcessInfoWrapper
    }
    
    private func assertIntegrationsInstalled(integrations: [String]) {
        XCTAssertEqual(integrations.count, SentrySDKInternal.currentHub().installedIntegrations().count)
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDKInternal.currentHub().isIntegrationInstalled(integrationClass), "\(integration) not installed")
            } else {
                XCTAssertTrue(SentrySDKInternal.currentHub().hasIntegration(integration), "\(integration) not installed with legacy ObjC API nor Swift")
            }
        }
    }

    private func givenSdkWithHubButNoClient() {
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))
        SentrySDK.setStart(with: fixture.options)
    }

    private func givenSdkWithHub() {
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDK.setStart(with: fixture.options)
    }
}
