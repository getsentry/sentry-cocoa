@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable file_length
class SentrySDKTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySDKTests")

    private class Fixture {
    
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
        }
    }

    private var fixture: Fixture!

    // MARK: - Helper Fixtures for Watchdog Termination Processors
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private func createWatchdogTerminationProcessors(fileManager: SentryFileManager, dispatchQueueWrapper: SentryDispatchQueueWrapper = SentryDispatchQueueWrapper()) -> (
        breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor,
        contextProcessor: SentryWatchdogTerminationContextProcessorWrapper,
        userProcessor: SentryWatchdogTerminationUserProcessorWrapper,
        tagsProcessor: SentryWatchdogTerminationTagsProcessorWrapper,
        levelProcessor: SentryWatchdogTerminationLevelProcessorWrapper,
        distProcessor: SentryWatchdogTerminationDistProcessorWrapper,
        environmentProcessor: SentryWatchdogTerminationEnvironmentProcessorWrapper,
        extrasProcessor: SentryWatchdogTerminationExtrasProcessorWrapper,
        fingerprintProcessor: SentryWatchdogTerminationFingerprintProcessorWrapper,
        traceContextProcessor: SentryWatchdogTerminationTraceContextProcessorWrapper
    ) {
        let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 10, fileManager: fileManager)
        let contextProcessor = SentryWatchdogTerminationContextProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeContextStore: TestSentryScopeContextPersistentStore(fileManager: fileManager)
        )
        let userProcessor = SentryWatchdogTerminationUserProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeUserStore: TestSentryScopeUserPersistentStore(fileManager: fileManager)
        )
        let tagsProcessor = SentryWatchdogTerminationTagsProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeTagsStore: TestSentryScopeTagsPersistentStore(fileManager: fileManager)
        )
        let levelProcessor = SentryWatchdogTerminationLevelProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeLevelStore: TestSentryScopeLevelPersistentStore(fileManager: fileManager)
        )
        let distProcessor = SentryWatchdogTerminationDistProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeDistStore: TestSentryScopeDistPersistentStore(fileManager: fileManager)
        )
        let environmentProcessor = SentryWatchdogTerminationEnvironmentProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeEnvironmentStore: TestSentryScopeEnvironmentPersistentStore(fileManager: fileManager)
        )
        let extrasProcessor = SentryWatchdogTerminationExtrasProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeExtrasStore: TestSentryScopeExtrasPersistentStore(fileManager: fileManager)
        )
        let fingerprintProcessor = SentryWatchdogTerminationFingerprintProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeFingerprintStore: TestSentryScopeFingerprintPersistentStore(fileManager: fileManager)
        )
        let traceContextProcessor = SentryWatchdogTerminationTraceContextProcessorWrapper(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopeTraceContextStore: TestSentryScopeTraceContextPersistentStore(fileManager: fileManager)
        )
        
        return (
            breadcrumbProcessor: breadcrumbProcessor,
            contextProcessor: contextProcessor,
            userProcessor: userProcessor,
            tagsProcessor: tagsProcessor,
            levelProcessor: levelProcessor,
            distProcessor: distProcessor,
            environmentProcessor: environmentProcessor,
            extrasProcessor: extrasProcessor,
            fingerprintProcessor: fingerprintProcessor,
            traceContextProcessor: traceContextProcessor
        )
    }
    
    private func createWatchdogTerminationObserver(fileManager: SentryFileManager, dispatchQueueWrapper: SentryDispatchQueueWrapper = SentryDispatchQueueWrapper()) -> SentryWatchdogTerminationScopeObserver {
        let processors = createWatchdogTerminationProcessors(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        return SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: processors.breadcrumbProcessor,
            contextProcessor: processors.contextProcessor,
            userProcessor: processors.userProcessor,
            tagsProcessor: processors.tagsProcessor,
            levelProcessor: processors.levelProcessor,
            distProcessor: processors.distProcessor,
            environmentProcessor: processors.environmentProcessor,
            extrasProcessor: processors.extrasProcessor,
            fingerprintProcessor: processors.fingerprintProcessor,
            traceContextProcessor: processors.traceContextProcessor
        )
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    @available(*, deprecated, message: "This is marked deprecated as a workaround (for the workaround deprecating the Fixture.init method) until we can remove SentryUserFeedback in favor of SentryFeedback. When SentryUserFeedback is removed, this deprecation annotation can be removed.")
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()

        givenSdkWithHubButNoClient()

        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations().first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }

        clearTestState()
    }

    // Repro for: https://github.com/getsentry/sentry-cocoa/issues/1325
    func testStartWithZeroMaxBreadcrumbsOptionsDoesNotCrash() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.maxBreadcrumbs = 0
            options.setIntegrations([])
        }

        SentrySDK.addBreadcrumb(Breadcrumb(level: SentryLevel.warning, category: "test"))
        let breadcrumbs = Dynamic(SentrySDK.currentHub().scope).breadcrumbArray as [Breadcrumb]?
        XCTAssertEqual(0, breadcrumbs?.count)
    }

    func testStartWithConfigureOptions() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.debug = true
            options.diagnosticLevel = SentryLevel.debug
            options.attachStacktrace = true
        }

        let hub = SentrySDK.currentHub()
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

    func testStartWithConfigureOptions_NoDsn() throws {
        SentrySDK.start { options in
            options.debug = true
            options.removeAllIntegrations()
        }

        let options = SentrySDK.currentHub().getClient()?.options
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

        let options = SentrySDK.currentHub().getClient()?.options
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
        XCTAssertEqual("me", SentrySDK.currentHub().scope.userObject?.userId)
        XCTAssertIdentical(scope, SentrySDK.currentHub().scope)
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

    func testDetectedStartUpCrash() {
        SentrySDK.setDetectedStartUpCrash(true)
        XCTAssertEqual(SentrySDK.detectedStartUpCrash, true)

        SentrySDK.setDetectedStartUpCrash(false)
        XCTAssertFalse(SentrySDK.detectedStartUpCrash)
    }

    func testCaptureFatalEvent() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)

        let event = fixture.event
        SentrySDK.captureFatalEvent(event)
    
        XCTAssertEqual(1, hub.sentFatalEvents.count)
        XCTAssertEqual(event.message, hub.sentFatalEvents.first?.message)
        XCTAssertEqual(event.eventId, hub.sentFatalEvents.first?.eventId)
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

    func testCaptureEnvelope() {
        givenSdkWithHub()

        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.capture(envelope)

        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.captureEnvelopeInvocations.first?.header.eventId)
    }

    func testStoreEnvelope() {
        givenSdkWithHub()

        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDK.store(envelope)

        XCTAssertEqual(1, fixture.client.storedEnvelopeInvocations.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.storedEnvelopeInvocations.first?.header.eventId)
    }

    /// This is to prevent https://github.com/getsentry/sentry-cocoa/issues/4280
    /// With 8.33.0, writing an envelope could fail in the middle of the process, which the envelope
    /// payload below simulates. The JSON stems from writing an envelope to disk with vast data
    /// that leads to an OOM termination on v 8.33.0.
    /// Running this test on v 8.33.0 leads to a crash.
    func testStartSDK_WithCorruptedEnvelope() throws {

        let fileManager = try SentryFileManager(options: fixture.options)

        let corruptedEnvelopeData = Data("""
                       {"event_id":"1990b5bc31904b7395fd07feb72daf1c","sdk":{"name":"sentry.cocoa","version":"8.33.0"}}
                       {"type":"test","length":50}
                       """.utf8)

        try corruptedEnvelopeData.write(to: URL(fileURLWithPath: "\(fileManager.envelopesPath)/corrupted-envelope.json"))

        SentrySDK.start(options: fixture.options)

        fileManager.deleteAllEnvelopes()
    }

    func testStoreEnvelope_WhenNoClient_NoCrash() {
        SentrySDK.store(SentryEnvelope(event: TestData.event))

        XCTAssertEqual(0, fixture.client.storedEnvelopeInvocations.count)
    }

    @available(*, deprecated, message: "-[SentrySDK captureUserFeedback:] is deprecated. -[SentrySDK captureFeedback:] is the new way. This test case can be removed in favor of testCaptureFeedback when -[SentrySDK captureUserFeedback:] is removed.")
    func testCaptureUserFeedback() {
        givenSdkWithHub()

        SentrySDK.capture(userFeedback: fixture.userFeedback)
        let client = fixture.client
        XCTAssertEqual(1, client.captureUserFeedbackInvocations.count)
        if let actual = client.captureUserFeedbackInvocations.first {
            let expected = fixture.userFeedback
            XCTAssertEqual(expected.eventId, actual.eventId)
            XCTAssertEqual(expected.name, actual.name)
            XCTAssertEqual(expected.email, actual.email)
            XCTAssertEqual(expected.comments, actual.comments)
        }
    }

    func testCaptureFeedback() {
        givenSdkWithHub()

        SentrySDK.capture(feedback: fixture.feedback)
        let client = fixture.client
        XCTAssertEqual(1, client.captureFeedbackInvocations.count)
        if let actual = client.captureFeedbackInvocations.first {
            let expected = fixture.feedback
            XCTAssertEqual(expected.eventId, actual.0.eventId)
            XCTAssertEqual(expected.name, actual.0.name)
            XCTAssertEqual(expected.email, actual.0.email)
            XCTAssertEqual(expected.message, actual.0.message)
        }
    }

    func testSetUser_SetsUserToScopeOfHub() {
        givenSdkWithHub()

        let user = TestData.user
        SentrySDK.setUser(user)

        let actualScope = SentrySDK.currentHub().scope
        let event = actualScope.applyTo(event: fixture.event, maxBreadcrumbs: 10)
        XCTAssertEqual(event?.user, user)
    }

    func testSetUserBeforeStartingSDK_LogsFatalMessage() throws {
        // Arrange
        let oldOutput = SentrySDKLog.getLogOutput()

        defer {
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)

        // Act
        SentrySDK.setUser(nil)
    
        // Assert
        let actualLogMessage = try XCTUnwrap(logOutput.loggedMessages.first)
        let expectedLogMessage = "The SDK is disabled, so setUser doesn't work. Please ensure to start the SDK before setting the user."

        XCTAssertTrue(actualLogMessage.contains(expectedLogMessage), "Expected log message to contain '\(expectedLogMessage)', but got '\(actualLogMessage)'")
    }

    func testSetUserAFterStartingSDK_DoesNotLogFatalMessage() {
        // Arrange
        let oldOutput = SentrySDKLog.getLogOutput()

        defer {
            SentrySDKLog.setOutput(oldOutput)
        }

        let logOutput = TestLogOutput()
        SentrySDKLog.setLogOutput(logOutput)

        givenSdkWithHub()

        let user = TestData.user

        // Act
        SentrySDK.setUser(user)

        //Assert
        XCTAssertEqual(0, logOutput.loggedMessages.count, "Expected no log messages, but got \(logOutput.loggedMessages.count)")
    }

    func testStartTransaction() throws {
        givenSdkWithHub()

        let operation = "ui.load"
        let name = "Load Main Screen"
        let transaction = SentrySDK.startTransaction(name: name, operation: operation)

        XCTAssertEqual(operation, transaction.operation)
        let tracer = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(name, tracer.traceContext?.transaction)

        XCTAssertNil(SentrySDK.span)
    }

    func testStartTransaction_WithBindToScope() throws {
        givenSdkWithHub()

        let transaction = SentrySDK.startTransaction(name: fixture.transactionName, operation: fixture.operation, bindToScope: true)

        XCTAssertEqual(fixture.operation, transaction.operation)
        let tracer = try XCTUnwrap(transaction as? SentryTracer)
        XCTAssertEqual(fixture.transactionName, tracer.traceContext?.transaction)
        XCTAssertEqual(.custom, tracer.transactionContext.nameSource)

        let newSpan = SentrySDK.span

        XCTAssert(transaction === newSpan)
    }

    func testInstallIntegrations() throws {
        let options = Options()
        options.dsn = "mine"
        options.integrations = ["SentryTestIntegration", "SentryTestIntegration", "IDontExist"]

        SentrySDK.start(options: options)

        assertIntegrationsInstalled(integrations: ["SentryTestIntegration"])
        let integration = SentrySDK.currentHub().installedIntegrations().first
        if let testIntegration = integration as? SentryTestIntegration {
            XCTAssertEqual(options.dsn, testIntegration.options.dsn)
            XCTAssertEqual(options.integrations, testIntegration.options.integrations)
        }
    }

    func testInstallIntegrations_NoIntegrations() {
        SentrySDK.start { options in
            options.removeAllIntegrations()
        }

        assertIntegrationsInstalled(integrations: [])
    }

    func testStartSession() {
        givenSdkWithHub()

        SentrySDK.startSession()

        XCTAssertEqual(1, fixture.client.captureSessionInvocations.count)

        let actual = fixture.client.captureSessionInvocations.first
        let expected = SentrySession(releaseName: fixture.options.releaseName ?? "", distinctId: "some-id")

        XCTAssertEqual(expected.flagInit, actual?.flagInit)
        XCTAssertEqual(expected.errors, actual?.errors)
        XCTAssertEqual(expected.sequence, actual?.sequence)
        XCTAssertEqual(expected.releaseName, actual?.releaseName)
        XCTAssertEqual(SentryDependencyContainer.sharedInstance().dateProvider.date(), actual?.started)
        XCTAssertEqual(SentrySessionStatus.ok, actual?.status)
        XCTAssertNil(actual?.timestamp)
        XCTAssertNil(actual?.duration)
    }

    func testEndSession() throws {
        givenSdkWithHub()

        SentrySDK.startSession()
        advanceTime(bySeconds: 1)
        SentrySDK.endSession()

        XCTAssertEqual(2, fixture.client.captureSessionInvocations.count)

        let actual = try XCTUnwrap(fixture.client.captureSessionInvocations.invocations.last)

        XCTAssertNil(actual.flagInit)
        XCTAssertEqual(0, actual.errors)
        XCTAssertEqual(2, actual.sequence)
        XCTAssertEqual(SentrySessionStatus.exited, actual.status)
        XCTAssertEqual(fixture.options.releaseName ?? "", actual.releaseName)
        XCTAssertEqual(1, actual.duration)
        XCTAssertEqual(SentryDependencyContainer.sharedInstance().dateProvider.date(), actual.timestamp)
    }

    func testGlobalOptions() {
        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDK.options, fixture.options)
    }

    func testGlobalOptionsForPreview() {
        startprocessInfoWrapperForPreview()

        SentrySDK.start(options: fixture.options)
        XCTAssertEqual(SentrySDK.options, fixture.options)
    }

#if SENTRY_HAS_UIKIT
    func testSetAppStartMeasurement_CallsPrivateSDKCallback() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)

        var callbackCalled = false
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = { measurement in
            XCTAssertEqual(appStartMeasurement, measurement)
            callbackCalled = true
        }

        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        XCTAssertTrue(callbackCalled)
    }

    func testSetAppStartMeasurement_NoCallback_CallbackNotCalled() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)

        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        XCTAssertEqual(SentrySDK.getAppStartMeasurement(), appStartMeasurement)
    }
#endif // SENTRY_HAS_UIKIT

    func testSDKStartInvocations() {
        XCTAssertEqual(0, SentrySDK.startInvocations)

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        XCTAssertEqual(1, SentrySDK.startInvocations)
    }

    func testSDKStartTimestamp() {
        let currentDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider

        XCTAssertNil(SentrySDK.startTimestamp)

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        XCTAssertEqual(SentrySDK.startTimestamp, currentDateProvider.date())

        SentrySDK.close()
        XCTAssertNil(SentrySDK.startTimestamp)
    }

    func testIsEnabled() {
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }
        XCTAssertTrue(SentrySDK.isEnabled)

        SentrySDK.close()
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }
        XCTAssertTrue(SentrySDK.isEnabled)
    }

    func testClose_ResetsDependencyContainer() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        let first = SentryDependencyContainer.sharedInstance()

        SentrySDK.close()

        let second = SentryDependencyContainer.sharedInstance()

        XCTAssertNotEqual(first, second)
    }

    func testClose_ClearsIntegrations() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.swiftAsyncStacktraces = true
            options.setIntegrations([SentrySwiftAsyncIntegration.self])
        }

        let hub = SentrySDK.currentHub()
        XCTAssertEqual(1, hub.installedIntegrations().count)
        SentrySDK.close()
        XCTAssertEqual(0, hub.installedIntegrations().count)
        assertIntegrationsInstalled(integrations: [])
    }

#if SENTRY_HAS_UIKIT
    func testClose_StopsAppStateManager() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.tracesSampleRate = 1
            options.removeAllIntegrations()
        }

        let appStateManager = SentryDependencyContainer.sharedInstance().appStateManager
        XCTAssertEqual(appStateManager.startCount, 1)

        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.tracesSampleRate = 1
            options.removeAllIntegrations()
        }

        XCTAssertEqual(appStateManager.startCount, 2)

        SentrySDK.close()

        XCTAssertEqual(appStateManager.startCount, 0)

        let stateAfterStop = fixture.fileManager.readAppState()
        XCTAssertFalse(stateAfterStop!.isSDKRunning)
    }
#endif

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testReportFullyDisplayed() {
        fixture.options.enableTimeToFullDisplayTracing = true

        let testTTDTracker = TestTimeToDisplayTracker(waitForFullDisplay: true)
        let performanceTracker = Dynamic(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
        performanceTracker.currentTTDTracker = testTTDTracker

        // Start SDK after setting up the tracker to ensure we're changing the tracker during it's initialization,
        // because some initialization logic happens on a BG thread and we would end up in a race condition.
        SentrySDK.start(options: fixture.options)

        SentrySDK.reportFullyDisplayed()

        XCTAssertTrue(testTTDTracker.registerFullDisplayCalled)
    }
#endif

#if os(iOS)
    func testSentryUIDeviceWrapperStarted() {
        let deviceWrapper = TestSentryUIDeviceWrapper()
        SentryDependencyContainer.sharedInstance().uiDeviceWrapper = deviceWrapper
        SentrySDK.start(options: fixture.options)
        XCTAssertTrue(deviceWrapper.started)
    }

    func testSentryUIDeviceWrapperStopped() {
        let deviceWrapper = TestSentryUIDeviceWrapper()
        SentryDependencyContainer.sharedInstance().uiDeviceWrapper = deviceWrapper
        SentrySDK.start(options: fixture.options)
        SentrySDK.close()
        XCTAssertFalse(deviceWrapper.started)
    }

    /// Ensure to start the UIDeviceWrapper before initializing the hub, so enrich scope sets the correct OS version.
    func testStartSDK_ScopeContextContainsOSVersion() throws {
        let expectation = expectation(description: "MainThreadTestIntegration install called")
        MainThreadTestIntegration.expectation = expectation

        DispatchQueue.global(qos: .default).async {
            SentrySDK.start { options in
                options.integrations = [ NSStringFromClass(MainThreadTestIntegration.self) ]
            }
        }

        wait(for: [expectation], timeout: 1.0)

        let os = try XCTUnwrap (SentrySDK.currentHub().scope.contextDictionary["os"] as? [String: Any])
#if !targetEnvironment(macCatalyst)
        XCTAssertEqual(UIDevice.current.systemVersion, os["version"] as? String)
#endif
    }
#endif

    func testResumeAndPauseAppHangTracking() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.setIntegrations([SentryANRTrackingIntegration.self])
        }

        let client = fixture.client
        SentrySDK.currentHub().bindClient(client)

        let anrTrackingIntegration = SentrySDK.currentHub().getInstalledIntegration(SentryANRTrackingIntegration.self)

        SentrySDK.pauseAppHangTracking()
        Dynamic(anrTrackingIntegration).anrDetectedWithType(SentryANRType.unknown)
        XCTAssertEqual(0, client.captureEventWithScopeInvocations.count)

        SentrySDK.resumeAppHangTracking()
        Dynamic(anrTrackingIntegration).anrDetectedWithType(SentryANRType.unknown)

        if SentryDependencyContainer.sharedInstance().crashWrapper.isBeingTraced() {
            XCTAssertEqual(0, client.captureEventWithScopeInvocations.count)
        } else {
            XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
        }
    }

    func testResumeAndPauseAppHangTracking_ANRTrackingNotInstalled() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        let client = fixture.client
        SentrySDK.currentHub().bindClient(client)

        // Both invocations do nothing
        SentrySDK.pauseAppHangTracking()
        SentrySDK.resumeAppHangTracking()
    }

    func testClose_SetsClientToNil() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        SentrySDK.close()

        XCTAssertNil(SentrySDK.currentHub().client())
    }

    func testClose_ClosesClient() {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        let client = SentrySDK.currentHub().client()
        SentrySDK.close()

        XCTAssertFalse(client?.isEnabled ?? true)
    }

    func testClose_CallsFlushCorrectlyOnTransport() throws {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        let transport = TestTransport()
        let client = SentryClient(options: fixture.options, fileManager: try TestFileManager(options: fixture.options), deleteOldEnvelopeItems: false)
        Dynamic(client).transportAdapter = TestTransportAdapter(transports: [transport], options: fixture.options)
        SentrySDK.currentHub().bindClient(client)
        SentrySDK.close()

        XCTAssertEqual(Options().shutdownTimeInterval, transport.flushInvocations.first)
    }

    func testFlush_CallsFlushCorrectlyOnTransport() throws {
        SentrySDK.start { options in
            options.dsn = SentrySDKTests.dsnAsString
            options.removeAllIntegrations()
        }

        let transport = TestTransport()
        let client = SentryClient(options: fixture.options, fileManager: try TestFileManager(options: fixture.options), deleteOldEnvelopeItems: false)
        Dynamic(client).transportAdapter = TestTransportAdapter(transports: [transport], options: fixture.options)
        SentrySDK.currentHub().bindClient(client)

        let flushTimeout = 10.0
        SentrySDK.flush(timeout: flushTimeout)

        XCTAssertEqual(flushTimeout, transport.flushInvocations.first)
    }

    func testStartOnTheMainThread() throws {
        let expectation = expectation(description: "MainThreadTestIntegration install called")
        MainThreadTestIntegration.expectation = expectation

        print("[Sentry] [TEST] [\(#file):\(#line) Dispatching to nonmain queue.")
        DispatchQueue.global(qos: .background).async {
            print("[Sentry] [TEST] [\(#file):\(#line) About to start SDK from nonmain queue.")
            SentrySDK.start { options in
                print("[Sentry] [TEST] [\(#file):\(#line) configuring options.")
                options.integrations = [ NSStringFromClass(MainThreadTestIntegration.self) ]
            }
        }

        wait(for: [expectation], timeout: 1.0)

        let mainThreadIntegration = try XCTUnwrap(SentrySDK.currentHub().installedIntegrations().first as? MainThreadTestIntegration)
        XCTAssert(mainThreadIntegration.installedInTheMainThread, "SDK is not being initialized in the main thread")

    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testSetAppStartMeasurementConcurrently() {
        let runtimeInitSystemTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()

        func setAppStartMeasurement(_ queue: DispatchQueue, _ i: Int) {
            group.enter()
            queue.async {
                let appStartTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(TimeInterval(i))
                let appStartMeasurement = TestData.getAppStartMeasurement(
                    type: .warm,
                    appStartTimestamp: appStartTimestamp,
                    runtimeInitSystemTimestamp: UInt64(runtimeInitSystemTimestamp.timeIntervalSince1970)
                )
                SentrySDK.setAppStartMeasurement(appStartMeasurement)
                group.leave()
            }
        }

        func createQueue() -> DispatchQueue {
            return DispatchQueue(label: "SentrySDKTests", qos: .userInteractive, attributes: [.initiallyInactive])
        }

        let queue1 = createQueue()
        let queue2 = createQueue()
        let group = DispatchGroup()

        let amount = 100

        for i in 0...amount {
            setAppStartMeasurement(queue1, i)
            setAppStartMeasurement(queue2, i)
        }

        queue1.activate()
        queue2.activate()
        group.waitWithTimeout(timeout: 100)

        let timestamp = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(TimeInterval(amount))
        XCTAssertEqual(timestamp, SentrySDK.getAppStartMeasurement()?.appStartTimestamp)
    }

    func testMovesBreadcrumbsToPreviousBreadcrumbs() throws {
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        let serializedBreadcrumb = TestData.crumb.serialize()

        for _ in 0..<3 {
            observer.addSerializedBreadcrumb(serializedBreadcrumb)
        }

        SentrySDK.start(options: options)

        let result = fileManager.readPreviousBreadcrumbs()
        XCTAssertEqual(result.count, 3)
    }

    func testStartWithOptions_shouldMoveCurrentContextFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the context store for assertions
        let scopeContextStore = TestSentryScopeContextPersistentStore(fileManager: fileManager)
        observer.setContext([
            "a": ["b": "c"]
        ])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setContext completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous context file if it exists
        scopeContextStore.deletePreviousContextOnDisk()
        // Sanity-check for the pre-condition
        let previousContext = scopeContextStore.readPreviousContextFromDisk()
        XCTAssertNil(previousContext)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeContextStore.readPreviousContextFromDisk())
        XCTAssertEqual(result.count, 1)
        let value = try XCTUnwrap(result["a"] as? [String: String])
        XCTAssertEqual(value["b"], "c")
    }
    
    func testStartWithOptions_shouldMoveCurrentUserFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the user store for assertions
        let scopeUserStore = TestSentryScopeUserPersistentStore(fileManager: fileManager)
        observer.setUser(User(userId: "1234"))

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setUser completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous user file if it exists
        scopeUserStore.deletePreviousUserOnDisk()
        // Sanity-check for the pre-condition
        let previousUser = scopeUserStore.readPreviousUserFromDisk()
        XCTAssertNil(previousUser)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeUserStore.readPreviousUserFromDisk())
        XCTAssertNotNil(result)
        XCTAssertEqual(result.userId, "1234")
    }
    
    func testStartWithOptions_shouldMoveCurrentTagsFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the tags store for assertions
        let scopeTagsStore = TestSentryScopeTagsPersistentStore(fileManager: fileManager)
        observer.setTags(["a": "b"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "set Tags completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous user file if it exists
        scopeTagsStore.deletePreviousTagsOnDisk()
        // Sanity-check for the pre-condition
        let previousUser = scopeTagsStore.readPreviousTagsFromDisk()
        XCTAssertNil(previousUser)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeTagsStore.readPreviousTagsFromDisk())
        XCTAssertEqual(result.count, 1)
        let value = try XCTUnwrap(result["a"])
        XCTAssertEqual(value, "b")
    }
    
    func testStartWithOptions_shouldMoveCurrentLevelFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the level store for assertions
        let scopeLevelStore = TestSentryScopeLevelPersistentStore(fileManager: fileManager)
        observer.setLevel(SentryLevel.debug)

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setLevel completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous user file if it exists
        scopeLevelStore.deletePreviousLevelOnDisk()
        // Sanity-check for the pre-condition
        let previousLevel = scopeLevelStore.readPreviousLevelFromDisk()
        XCTAssertEqual(previousLevel, SentryLevel.error) // Error is the default level

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeLevelStore.readPreviousLevelFromDisk())
        XCTAssertEqual(result, SentryLevel.debug)
    }
    
    func testStartWithOptions_shouldMoveCurrentDistFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the dist store for assertions
        let scopeDistStore = TestSentryScopeDistPersistentStore(fileManager: fileManager)
        observer.setDist("test-dist")

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setDist completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the dist processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous dist file if it exists
        scopeDistStore.deletePreviousDistOnDisk()
        // Sanity-check for the pre-condition
        let previousDist = scopeDistStore.readPreviousDistFromDisk()
        XCTAssertNil(previousDist)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeDistStore.readPreviousDistFromDisk())
        XCTAssertEqual(result, "test-dist")
    }
    
    func testStartWithOptions_shouldMoveCurrentEnvironmentFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the environment store for assertions
        let scopeEnvironmentStore = TestSentryScopeEnvironmentPersistentStore(fileManager: fileManager)
        observer.setEnvironment("test-environment")

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setEnvironment completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the environment processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous environment file if it exists
        scopeEnvironmentStore.deletePreviousEnvironmentOnDisk()
        // Sanity-check for the pre-condition
        let previousEnvironment = scopeEnvironmentStore.readPreviousEnvironmentFromDisk()
        XCTAssertNil(previousEnvironment)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeEnvironmentStore.readPreviousEnvironmentFromDisk())
        XCTAssertEqual(result, "test-environment")
    }
    
    func testStartWithOptions_shouldMoveCurrentExtrasFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the extras store for assertions
        let scopeExtrasStore = TestSentryScopeExtrasPersistentStore(fileManager: fileManager)
        observer.setExtras(["extra-key": "extra-value"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setExtras completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the extras processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous extras file if it exists
        scopeExtrasStore.deletePreviousExtrasOnDisk()
        // Sanity-check for the pre-condition
        let previousExtras = scopeExtrasStore.readPreviousExtrasFromDisk()
        XCTAssertNil(previousExtras)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeExtrasStore.readPreviousExtrasFromDisk())
        XCTAssertEqual(result.count, 1)
        let value = try XCTUnwrap(result["extra-key"] as? String)
        XCTAssertEqual(value, "extra-value")
    }
    
    func testStartWithOptions_shouldMoveCurrentFingerprintFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the fingerprint store for assertions
        let scopeFingerprintStore = TestSentryScopeFingerprintPersistentStore(fileManager: fileManager)
        observer.setFingerprint(["fingerprint1", "fingerprint2"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setFingerprint completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the fingerprint processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous fingerprint file if it exists
        scopeFingerprintStore.deletePreviousFingerprintOnDisk()
        // Sanity-check for the pre-condition
        let previousFingerprint = scopeFingerprintStore.readPreviousFingerprintFromDisk()
        XCTAssertNil(previousFingerprint)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeFingerprintStore.readPreviousFingerprintFromDisk())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], "fingerprint1")
        XCTAssertEqual(result[1], "fingerprint2")
    }
    
    func testStartWithOptions_shouldMoveCurrentTraceContextFileToPreviousFile() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentrySDKTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let observer = createWatchdogTerminationObserver(fileManager: fileManager, dispatchQueueWrapper: dispatchQueueWrapper)
        
        // Get the trace context store for assertions
        let scopeTraceContextStore = TestSentryScopeTraceContextPersistentStore(fileManager: fileManager)
        observer.setTraceContext(["trace_id": "abc123", "span_id": "def456"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setTraceContext completes")
        dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the trace context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous trace context file if it exists
        scopeTraceContextStore.deletePreviousTraceContextOnDisk()
        // Sanity-check for the pre-condition
        let previousTraceContext = scopeTraceContextStore.readPreviousTraceContextFromDisk()
        XCTAssertNil(previousTraceContext)

        // -- Act --
        SentrySDK.start(options: options)

        // -- Assert --
        let result = try XCTUnwrap(scopeTraceContextStore.readPreviousTraceContextFromDisk())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["trace_id"] as? String, "abc123")
        XCTAssertEqual(result["span_id"] as? String, "def456")
    }

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
#if os(macOS)
    func testCaptureCrashOnException() {
        givenSdkWithHub()
        
        SentrySDK.captureCrashOn(exception: fixture.exception)

        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count)
        XCTAssertNotEqual(fixture.exception, client.captureExceptionWithScopeInvocations.first?.exception)
        XCTAssertEqual(fixture.exception.name, client.captureExceptionWithScopeInvocations.first?.exception.name)
        XCTAssertEqual(fixture.exception.reason, client.captureExceptionWithScopeInvocations.first?.exception.reason)
        XCTAssertEqual(fixture.scope, client.captureExceptionWithScopeInvocations.first?.scope)
    }
#endif // os(macOS)
}

private extension SentrySDKTests {
    func givenSdkWithHub() {
        SentrySDK.setCurrentHub(fixture.hub)
        SentrySDK.setStart(fixture.options)
    }

    func givenSdkWithHubButNoClient() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
        SentrySDK.setStart(fixture.options)
    }

    func assertIntegrationsInstalled(integrations: [String]) {
        XCTAssertEqual(integrations.count, SentrySDK.currentHub().installedIntegrations().count)
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDK.currentHub().isIntegrationInstalled(integrationClass), "\(integration) not installed")
            } else {
                XCTFail("Integration \(integration) not installed.")
            }
        }
    }

    func assertEventCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
        XCTAssertEqual(fixture.event, client.captureEventWithScopeInvocations.first?.event)
        XCTAssertEqual(expectedScope, client.captureEventWithScopeInvocations.first?.scope)
    }

    func assertErrorCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureErrorWithScopeInvocations.count)
        XCTAssertEqual(fixture.error.localizedDescription, client.captureErrorWithScopeInvocations.first?.error.localizedDescription)
        XCTAssertEqual(expectedScope, client.captureErrorWithScopeInvocations.first?.scope)
    }

    func assertExceptionCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count)
        XCTAssertEqual(fixture.exception, client.captureExceptionWithScopeInvocations.first?.exception)
        XCTAssertEqual(expectedScope, client.captureExceptionWithScopeInvocations.first?.scope)
    }

    func assertMessageCaptured(expectedScope: Scope) {
        let client = fixture.client
        XCTAssertEqual(1, client.captureMessageWithScopeInvocations.count)
        XCTAssertEqual(fixture.message, client.captureMessageWithScopeInvocations.first?.message)
        XCTAssertEqual(expectedScope, client.captureMessageWithScopeInvocations.first?.scope)
    }

    func assertHubScopeNotChanged() {
        let hubScope = SentrySDK.currentHub().scope
        XCTAssertEqual(fixture.scope, hubScope)
    }

    func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }

    func startprocessInfoWrapperForPreview() {
        let testProcessInfoWrapper = TestSentryNSProcessInfoWrapper()
        testProcessInfoWrapper.overrides.environment = ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        SentryDependencyContainer.sharedInstance().processInfoWrapper = testProcessInfoWrapper
    }
}

/// Tests in this class aren't part of SentrySDKTests because we need would need to undo a bunch of operations
/// that are done in the setup.
class SentrySDKWithSetupTests: XCTestCase {

    func testAccessingHubAndOptions_NoDeadlock() {
        let concurrentQueue = DispatchQueue(label: "concurrent", attributes: .concurrent)

        let expectation = expectation(description: "no deadlock")
        expectation.expectedFulfillmentCount = 20

        SentrySDK.setStart(Options())

        for _ in 0..<10 {
            concurrentQueue.async {
                SentrySDK.currentHub().capture(message: "mess")
                SentrySDK.setCurrentHub(nil)

                expectation.fulfill()
            }

            concurrentQueue.async {
                let hub = SentryHub(client: nil, andScope: nil)
                XCTAssertNotNil(hub)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}

public class MainThreadTestIntegration: NSObject, SentryIntegrationProtocol {

    static var expectation: XCTestExpectation?

    public var installedInTheMainThread = false

    public func install(with options: Options) -> Bool {
        print("[Sentry] [TEST] [\(#file):\(#line) starting install.")
        installedInTheMainThread = Thread.isMainThread
        MainThreadTestIntegration.expectation?.fulfill()
        MainThreadTestIntegration.expectation = nil
        return true
    }

    public func uninstall() {
    }
}
// swiftlint:enable file_length
