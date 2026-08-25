@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
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

#if os(iOS) || os(tvOS)
        let observer: SentryWatchdogTerminationScopeObserver
        let scopePersistentStore: TestSentryScopePersistentStore
#endif //  os(iOS) || os(tvOS)

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
            hub = SentryHubInternal(client: client, andScope: scope, activeCrashReporterState: TestSentryCrashReporterState(), andDispatchQueue: SentryDispatchQueueWrapper())

            feedback = SentryFeedback(message: "Again really?", name: "Tim Apple", email: "tim@apple.com")
            
#if os(iOS) || os(tvOS)
            options.dsn = SentrySDKTests.dsnAsString

            let fileManager = try XCTUnwrap(TestFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueueWrapper
            ))
            let breadcrumbProcessor = SentryDefaultWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: 10,
                fileManager: fileManager,
                dispatchQueueWrapper: dispatchQueueWrapper
            )
            scopePersistentStore = try XCTUnwrap(TestSentryScopePersistentStore(fileManager: fileManager))
            let attributesProcessor = SentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchQueueWrapper,
                scopePersistentStore: scopePersistentStore
            )
            observer = SentryWatchdogTerminationScopeObserver(breadcrumbProcessor: breadcrumbProcessor, attributesProcessor: attributesProcessor)
#endif //  os(iOS) || os(tvOS)
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

        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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
            "SentryAutoBreadcrumbTrackingIntegration",
            "SentryAutoSessionTrackingIntegration",
            "SentryMetricsIntegration",
            "SentryNetworkTrackingIntegration"
        ]
#if !SDK_V10
        if !SentryDependencyContainer.sharedInstance().debuggerStatusProvider.isBeingTraced {
            expectedIntegrations.append("SentryANRTrackingIntegration")
        }
#endif
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SDK_V10
        expectedIntegrations.append("SentryFramesTrackingIntegration")
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SDK_V10
        #if SDK_V10
        expectedIntegrations.append("SentryKSCrashIntegration")
        #else
        expectedIntegrations.append("SentryCrashIntegration")
        #endif
        #if SDK_V10 && !SENTRY_DISABLE_SENTRYCRASH_V10
        expectedIntegrations.append("SentrySwiftAsyncIntegration")
        #elseif SDK_V10
        // KSCRASH_TODO(GH-8725): V10 temporarily omits the Swift async integration.
        // Acceptance: SCV10-011 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        #endif
#if canImport(MetricKit) && !os(tvOS) && SDK_V10
        expectedIntegrations.append("SentryMetricKitIntegration")
#endif

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

    #if !SDK_V10
    @available(*, deprecated, message: "Testing deprecated crashedLastRun API")
    func testCrashedLastRun() {
        XCTAssertEqual(
            SentryDependencyContainer.sharedInstance().activeCrashReporterState.crashedLastLaunch,
            SentrySDK.crashedLastRun
        )
    }
    #endif

    // MARK: - lastRunStatus

    func testLastRunStatus_whenCrashStateNotLoaded_shouldReturnUnknown() {
        // -- Arrange --
#if SDK_V10
        let mockQuery = MockKSCrashQuery.create(installed: false, crashedLastLaunch: false)
        SentryDependencyContainer.sharedInstance().kscrashQuery = mockQuery
#else
        let crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        crashWrapper.internalInstalled = false
        SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
#endif

        // -- Act --
        let status = SentrySDK.lastRunStatus

        // -- Assert --
        XCTAssertEqual(status, .unknown)
    }

    func testLastRunStatus_whenCrashStateLoadedAndNoCrash_shouldReturnDidNotCrash() {
        // -- Arrange --
#if SDK_V10
        let mockQuery = MockKSCrashQuery.create(installed: true, crashedLastLaunch: false)
        SentryDependencyContainer.sharedInstance().kscrashQuery = mockQuery
#else
        let crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        crashWrapper.internalInstalled = true
        crashWrapper.internalCrashedLastLaunch = false
        SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
#endif

        // -- Act --
        let status = SentrySDK.lastRunStatus

        // -- Assert --
        XCTAssertEqual(status, .didNotCrash)
    }

    func testLastRunStatus_whenCrashStateLoadedAndCrashed_shouldReturnDidCrash() {
        // -- Arrange --
#if SDK_V10
        let mockQuery = MockKSCrashQuery.create(installed: true, crashedLastLaunch: true)
        SentryDependencyContainer.sharedInstance().kscrashQuery = mockQuery
#else
        let crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        crashWrapper.internalInstalled = true
        crashWrapper.internalCrashedLastLaunch = true
        SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
#endif

        // -- Act --
        let status = SentrySDK.lastRunStatus

        // -- Assert --
        XCTAssertEqual(status, .didCrash)
    }

    func testLastRunStatus_afterClose_shouldReturnUnknown() {
        // -- Arrange --
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
        }
        SentrySDK.close()

        // -- Act --
        let status = SentrySDK.lastRunStatus

        // -- Assert --
        XCTAssertEqual(status, .unknown)
        XCTAssertFalse(SentrySDKInternal.crashReporterInstalled)
    }

    // MARK: - onLastRunStatusDetermined

    func testOnLastRunStatusDetermined_whenNoCrash_shouldCallWithDidNotCrash() {
        // -- Arrange --
        var receivedStatus: SentryLastRunStatus?
        var receivedEvent: Event?

        // -- Act --
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
            Self.givenDeterministicNoCrashState(options)
            options.onLastRunStatusDetermined = { status, event in
                receivedStatus = status
                receivedEvent = event
            }
        }

        // -- Assert --
        XCTAssertEqual(receivedStatus, .didNotCrash)
        XCTAssertNil(receivedEvent)
    }

    func testOnLastRunStatusDetermined_whenNoCrash_shouldSetLastRunStatusCalled() {
        // -- Act --
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
            Self.givenDeterministicNoCrashState(options)
            options.onLastRunStatusDetermined = { _, _ in }
        }

        // -- Assert --
        XCTAssertTrue(SentrySDKInternal.lastRunStatusCalled)
    }

    func testOnLastRunStatusDetermined_whenNoCallback_shouldNotCrash() {
        // -- Act & Assert -- (should not crash)
        SentrySDK.start { options in
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
            Self.givenDeterministicNoCrashState(options)
            options.onLastRunStatusDetermined = nil
        }
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

    func testCaptureEvent_withAttachAllThreads_setsOverrideOnEvent() {
        givenSdkWithHub()

        SentrySDK.capture(event: fixture.event, attachAllThreads: true)

        let client = fixture.client
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
        XCTAssertEqual(NSNumber(value: true), client.captureEventWithScopeInvocations.first?.event.attachAllThreadsOverride)
    }

    func testCaptureError_withAttachAllThreads_forwardsToClient() {
        givenSdkWithHub()

        SentrySDK.capture(error: fixture.error, attachAllThreads: true)

        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeAttachAllThreadsInvocations.count)
        XCTAssertEqual(NSNumber(value: true), client.captureErrorWithScopeAttachAllThreadsInvocations.first?.attachAllThreads)
    }

    func testCaptureException_withAttachAllThreads_forwardsToClient() {
        givenSdkWithHub()

        SentrySDK.capture(exception: fixture.exception, attachAllThreads: true)

        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeAttachAllThreadsInvocations.count)
        XCTAssertEqual(NSNumber(value: true), client.captureExceptionWithScopeAttachAllThreadsInvocations.first?.attachAllThreads)
    }

    func testCaptureMessage_withAttachAllThreads_forwardsToClient() {
        givenSdkWithHub()

        SentrySDK.capture(message: fixture.message, attachAllThreads: true)

        let client = fixture.client
        XCTAssertEqual(1, client.captureMessageWithScopeAttachAllThreadsInvocations.count)
        XCTAssertEqual(NSNumber(value: true), client.captureMessageWithScopeAttachAllThreadsInvocations.first?.attachAllThreads)
    }

    func testAddFeatureFlag_mutatesCurrentHubScope() throws {
        givenSdkWithHub()

        SentrySDK.addFeatureFlag(name: "checkout", result: true)

        let values = try featureFlagValues(from: fixture.scope)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.element(at: 0)?["flag"] as? String, "checkout")
        XCTAssertEqual(values.element(at: 0)?["result"] as? Bool, true)
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
        #if !SDK_V10
        fixture.client.options.enableLogs = true
        #endif // !SDK_V10
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDK.setStart(with: fixture.client.options)
        
        // Add a log to ensure there's something to flush
        SentrySDK.logger.info("Test log message")
        
        // Verify the log was captured
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
        XCTAssertEqual(fixture.client.captureLogInvocations.first?.log.body, "Test log message")
        
        // Flush the SDK - this should trigger the log buffer to flush
        SentrySDK.flush(timeout: 1.0)
        
        // The log should still be captured (flush doesn't clear the invocations)
        XCTAssertEqual(fixture.client.captureLogInvocations.count, 1)
    }
    
    func testClose_CallsLoggerCaptureLogs() {
        #if !SDK_V10
        fixture.client.options.enableLogs = true
        #endif // !SDK_V10
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

    private func featureFlagValues(from scope: Scope) throws -> [[String: Any]] {
        let context = try XCTUnwrap(scope.serialize()["context"] as? [String: Any])
        let flags = try XCTUnwrap(context["flags"] as? [String: Any])
        return try XCTUnwrap(flags["values"] as? [[String: Any]])
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

    private static func givenDeterministicNoCrashState(_ options: Options) {
#if SDK_V10
        // KSCrash state is process-lifetime and may contain a crash from another test. Disable the
        // real integration and inject the state required by these callback-focused tests.
        options.enableCrashHandler = false
        SentryDependencyContainer.sharedInstance().activeCrashReporterStateOverride =
            MockKSCrashQuery.create(installed: true, crashedLastLaunch: false)
#endif
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
