@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// swiftlint:disable file_length
class SentrySDKInternalTests: XCTestCase {

    private static let dsnAsString = TestConstants.dsnAsString(username: "SentrySDKTests")

    private class Fixture {
    
        let options: Options = {
            let options = Options.noIntegrations()
            options.dsn = SentrySDKInternalTests.dsnAsString
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
            options.dsn = SentrySDKInternalTests.dsnAsString

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

    func testDetectedStartUpCrash() {
        SentrySDKInternal.setDetectedStartUpCrash(true)
        XCTAssertEqual(SentrySDK.detectedStartUpCrash, true)

        SentrySDKInternal.setDetectedStartUpCrash(false)
        XCTAssertFalse(SentrySDK.detectedStartUpCrash)
    }

    func testCaptureFatalEvent() {
        let hub = TestHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)

        let event = fixture.event
        SentrySDKInternal.captureFatalEvent(event)
    
        XCTAssertEqual(1, hub.sentFatalEvents.count)
        XCTAssertEqual(event.message, hub.sentFatalEvents.first?.message)
        XCTAssertEqual(event.eventId, hub.sentFatalEvents.first?.eventId)
    }

    func testCaptureEnvelope() {
        givenSdkWithHub()

        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDKInternal.capture(envelope)

        XCTAssertEqual(1, fixture.client.captureEnvelopeInvocations.count)
        XCTAssertEqual(envelope.header.eventId, fixture.client.captureEnvelopeInvocations.first?.header.eventId)
    }

    func testStoreEnvelope() {
        givenSdkWithHub()

        let envelope = SentryEnvelope(event: TestData.event)
        SentrySDKInternal.store(envelope)

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
        SentrySDKInternal.store(SentryEnvelope(event: TestData.event))

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

    func testSetUser_SetsUserToScopeOfHub() {
        givenSdkWithHub()

        let user = TestData.user
        SentrySDK.setUser(user)

        let actualScope = SentrySDKInternal.currentHub().scope
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
        let integration = SentrySDKInternal.currentHub().installedIntegrations().first
        if let testIntegration = integration as? SentryTestIntegration {
            XCTAssertEqual(options.dsn, testIntegration.options.dsn)
            XCTAssertEqual(options.integrations, testIntegration.options.integrations)
        }
    }

#if SENTRY_HAS_UIKIT
    func testSetAppStartMeasurement_CallsPrivateSDKCallback() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)

        var callbackCalled = false
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = { measurement in
            XCTAssertEqual(appStartMeasurement, measurement)
            callbackCalled = true
        }

        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        XCTAssertTrue(callbackCalled)
    }

    func testSetAppStartMeasurement_NoCallback_CallbackNotCalled() {
        let appStartMeasurement = TestData.getAppStartMeasurement(type: .warm)

        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)

        XCTAssertEqual(SentrySDKInternal.getAppStartMeasurement(), appStartMeasurement)
    }
#endif // SENTRY_HAS_UIKIT

    func testSDKStartInvocations() {
        XCTAssertEqual(0, SentrySDKInternal.startInvocations)

        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        XCTAssertEqual(1, SentrySDKInternal.startInvocations)
    }

    func testSDKStartTimestamp() {
        let currentDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider

        XCTAssertNil(SentrySDKInternal.startTimestamp)

        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        XCTAssertEqual(SentrySDKInternal.startTimestamp, currentDateProvider.date())

        SentrySDK.close()
        XCTAssertNil(SentrySDKInternal.startTimestamp)
    }

    func testIsEnabled() {
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }
        XCTAssertTrue(SentrySDK.isEnabled)

        SentrySDK.close()
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.capture(message: "message")
        XCTAssertFalse(SentrySDK.isEnabled)

        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }
        XCTAssertTrue(SentrySDK.isEnabled)
    }

    func testClose_ResetsDependencyContainer() {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        let first = SentryDependencyContainer.sharedInstance()

        SentrySDK.close()

        let second = SentryDependencyContainer.sharedInstance()

        XCTAssertNotEqual(first, second)
    }

    func testClose_ClearsIntegrations() {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.swiftAsyncStacktraces = true
            options.setIntegrations([SentrySwiftAsyncIntegration.self])
        }

        let hub = SentrySDKInternal.currentHub()
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

        let os = try XCTUnwrap (SentrySDKInternal.currentHub().scope.contextDictionary["os"] as? [String: Any])
#if !targetEnvironment(macCatalyst)
        XCTAssertEqual(UIDevice.current.systemVersion, os["version"] as? String)
#endif
    }
#endif

    func testResumeAndPauseAppHangTracking() {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.setIntegrations([SentryANRTrackingIntegration.self])
        }

        let client = fixture.client
        SentrySDKInternal.currentHub().bindClient(client)

        let anrTrackingIntegration = SentrySDKInternal.currentHub().getInstalledIntegration(SentryANRTrackingIntegration.self)

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
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        let client = fixture.client
        SentrySDKInternal.currentHub().bindClient(client)

        // Both invocations do nothing
        SentrySDK.pauseAppHangTracking()
        SentrySDK.resumeAppHangTracking()
    }

    func testClose_SetsClientToNil() {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        SentrySDK.close()

        XCTAssertNil(SentrySDKInternal.currentHub().client())
    }

    func testClose_ClosesClient() {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        let client = SentrySDKInternal.currentHub().client()
        SentrySDK.close()

        XCTAssertFalse(client?.isEnabled ?? true)
    }

    func testClose_CallsFlushCorrectlyOnTransport() throws {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        let transport = TestTransport()
        let client = SentryClient(options: fixture.options, fileManager: try TestFileManager(options: fixture.options), deleteOldEnvelopeItems: false)
        Dynamic(client).transportAdapter = TestTransportAdapter(transports: [transport], options: fixture.options)
        SentrySDKInternal.currentHub().bindClient(client)
        SentrySDK.close()

        XCTAssertEqual(Options().shutdownTimeInterval, transport.flushInvocations.first)
    }
    
    func testLogger_ReturnsSameInstanceOnMultipleCalls() {
        givenSdkWithHub()
        
        let logger1 = SentrySDK.logger
        let logger2 = SentrySDK.logger
        
        XCTAssertIdentical(logger1, logger2)
    }

    func testClose_ResetsLogger() {
        givenSdkWithHub()
        
        // Get logger instance
        let logger1 = SentrySDK.logger
        XCTAssertNotNil(logger1)
        
        // Close SDK
        SentrySDK.close()
        
        // Start SDK again
        givenSdkWithHub()
        
        // Get logger instance again
        let logger2 = SentrySDK.logger
        XCTAssertNotNil(logger2)
        
        // Should be a different instance
        XCTAssertNotIdentical(logger1, logger2)
    }

    func testLogger_WithLogsEnabled_CapturesLog() {
        fixture.client.options.experimental.enableLogs = true
        givenSdkWithHub()
        
        SentrySDK.logger.error(String(repeating: "S", count: 1_024 * 1_024))
        
        let expectation = self.expectation(description: "Wait for async add.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
        
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 1)
    }

    func testLogger_WithNoClient_DoesNotCaptureLog() {
        fixture.client.options.experimental.enableLogs = true
        let hubWithoutClient = SentryHub(client: nil, andScope: nil)
        SentrySDKInternal.setCurrentHub(hubWithoutClient)
        
        SentrySDK.logger.error(String(repeating: "S", count: 1_024 * 1_024))
        
        let expectation = self.expectation(description: "Wait for async add.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
        
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 0)
    }
    
    func testLogger_WithLogsDisabled_DoesNotCaptureLog() {
        fixture.client.options.experimental.enableLogs = false
        givenSdkWithHub()
        
        SentrySDK.logger.error("foo")
        XCTAssertEqual(fixture.client.captureLogsDataInvocations.count, 0)
    }
    
    func testFlush_CallsFlushCorrectlyOnTransport() throws {
        SentrySDK.start { options in
            options.dsn = SentrySDKInternalTests.dsnAsString
            options.removeAllIntegrations()
        }

        let transport = TestTransport()
        let client = SentryClient(options: fixture.options, fileManager: try TestFileManager(options: fixture.options), deleteOldEnvelopeItems: false)
        Dynamic(client).transportAdapter = TestTransportAdapter(transports: [transport], options: fixture.options)
        SentrySDKInternal.currentHub().bindClient(client)

        let flushTimeout = 10.0
        SentrySDK.flush(timeout: flushTimeout)

        XCTAssertEqual(flushTimeout, transport.flushInvocations.first)
    }

    func testStartOnTheMainThread() throws {
        let expectation = expectation(description: "MainThreadTestIntegration install called")
        MainThreadTestIntegration.expectation = expectation

        print("[Sentry] [TEST] [\(#file):\(#line) Dispatching to nonmain queue.")
        DispatchQueue.global(qos: .utility).async {
            print("[Sentry] [TEST] [\(#file):\(#line) About to start SDK from nonmain queue.")
            SentrySDK.start { options in
                print("[Sentry] [TEST] [\(#file):\(#line) configuring options.")
                options.integrations = [ NSStringFromClass(MainThreadTestIntegration.self) ]
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let mainThreadIntegration = try XCTUnwrap(SentrySDKInternal.currentHub().installedIntegrations().first as? MainThreadTestIntegration)
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
                SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
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
        XCTAssertEqual(timestamp, SentrySDKInternal.getAppStartMeasurement()?.appStartTimestamp)
    }

    func testMovesBreadcrumbsToPreviousBreadcrumbs() throws {
        let options = Options()
        options.dsn = SentrySDKInternalTests.dsnAsString

        let fileManager = try TestFileManager(options: options)
        let breadcrumbProcessor = SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: 10, fileManager: fileManager)
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let scopePersistentStore = try XCTUnwrap(TestSentryScopePersistentStore(fileManager: fileManager))
        let attributesProcessor = SentryWatchdogTerminationAttributesProcessor(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            scopePersistentStore: scopePersistentStore
        )
        let observer = SentryWatchdogTerminationScopeObserver(breadcrumbProcessor: breadcrumbProcessor, attributesProcessor: attributesProcessor)
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
        fixture.observer.setContext([
            "a": ["b": "c"]
        ])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setContext completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous context file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousContext = fixture.scopePersistentStore.readPreviousContextFromDisk()
        XCTAssertNil(previousContext)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousContextFromDisk())
        XCTAssertEqual(result.count, 1)
        let value = try XCTUnwrap(result["a"] as? [String: String])
        XCTAssertEqual(value["b"], "c")
    }
    
    func testStartWithOptions_shouldMoveCurrentUserFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setUser(User(userId: "user1234"))

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setUser completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous context file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousUser = fixture.scopePersistentStore.readPreviousUserFromDisk()
        XCTAssertNil(previousUser)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousUserFromDisk())
        XCTAssertEqual(result.userId, "user1234")
    }
    
    func testStartWithOptions_shouldMoveCurrentDistFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setDist("dist-string")

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setDist completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        // Delete the previous context file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousUser = fixture.scopePersistentStore.readPreviousDistFromDisk()
        XCTAssertNil(previousUser)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousDistFromDisk())
        XCTAssertEqual(result, "dist-string")
    }

    func testStartWithOptions_shouldMoveCurrentEnvironmentFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setEnvironment("prod-string")

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setEnvironment completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        // Delete the previous context file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousUser = fixture.scopePersistentStore.readPreviousEnvironmentFromDisk()
        XCTAssertNil(previousUser)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousEnvironmentFromDisk())
        XCTAssertEqual(result, "prod-string")
    }

    func testStartWithOptions_shouldMoveCurrentExtraFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setExtras(["extra1": "value1", "extra2": "value2"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setExtras completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        // Delete the previous context file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        
        // Sanity-check for the pre-condition
        let previousExtras = fixture.scopePersistentStore.readPreviousExtrasFromDisk()
        XCTAssertNil(previousExtras)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousExtrasFromDisk())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["extra1"] as? String, "value1")
        XCTAssertEqual(result["extra2"] as? String, "value2")
    }

    func testStartWithOptions_shouldMoveCurrentFingerprintFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setFingerprint(["fingerprint1", "fingerprint2"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setFingerprint completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous fingerprint file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousFingerprint = fixture.scopePersistentStore.readPreviousFingerprintFromDisk()
        XCTAssertNil(previousFingerprint)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousFingerprintFromDisk())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], "fingerprint1")
        XCTAssertEqual(result[1], "fingerprint2")
    }
    
    func testStartWithOptions_shouldMoveCurrentTagsFileToPreviousFile() throws {
        // -- Arrange --
        fixture.observer.setTags(["tag1": "value1", "tag2": "value2"])

        // Wait for the observer to complete
        let expectation = XCTestExpectation(description: "setTags completes")
        fixture.dispatchQueueWrapper.dispatchAsync {
            // Dispatching a block on the same queue will be run after the context processor.
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Delete the previous tags file if it exists
        fixture.scopePersistentStore.deleteAllPreviousState()
        // Sanity-check for the pre-condition
        let previousTags = fixture.scopePersistentStore.readPreviousTagsFromDisk()
        XCTAssertNil(previousTags)

        // -- Act --
        SentrySDK.start(options: fixture.options)

        // -- Assert --
        let result = try XCTUnwrap(fixture.scopePersistentStore.readPreviousTagsFromDisk())
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result["tag1"], "value1")
        XCTAssertEqual(result["tag2"], "value2")
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
#if os(macOS)
    func testCaptureCrashOnException() {
        givenSdkWithHub()
        
        SentrySDKInternal.captureCrashOn(exception: fixture.exception)

        let client = fixture.client
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count)
        XCTAssertNotEqual(fixture.exception, client.captureExceptionWithScopeInvocations.first?.exception)
        XCTAssertEqual(fixture.exception.name, client.captureExceptionWithScopeInvocations.first?.exception.name)
        XCTAssertEqual(fixture.exception.reason, client.captureExceptionWithScopeInvocations.first?.exception.reason)
        XCTAssertEqual(fixture.scope, client.captureExceptionWithScopeInvocations.first?.scope)
    }
#endif // os(macOS)
}

private extension SentrySDKInternalTests {
    func givenSdkWithHub() {
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDKInternal.setStart(with: fixture.options)
    }

    func givenSdkWithHubButNoClient() {
        SentrySDKInternal.setCurrentHub(SentryHub(client: nil, andScope: nil))
        SentrySDKInternal.setStart(with: fixture.options)
    }
    
    func assertIntegrationsInstalled(integrations: [String]) {
        XCTAssertEqual(integrations.count, SentrySDKInternal.currentHub().installedIntegrations().count)
        integrations.forEach { integration in
            if let integrationClass = NSClassFromString(integration) {
                XCTAssertTrue(SentrySDKInternal.currentHub().isIntegrationInstalled(integrationClass), "\(integration) not installed")
            } else {
                XCTFail("Integration \(integration) not installed.")
            }
        }
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}

/// Tests in this class aren't part of SentrySDKTests because we need would need to undo a bunch of operations
/// that are done in the setup.
class SentrySDKWithSetupTests: XCTestCase {

    func testAccessingHubAndOptions_NoDeadlock() {
        let concurrentQueue = DispatchQueue(label: "concurrent", attributes: .concurrent)

        let expectation = expectation(description: "no deadlock")
        expectation.expectedFulfillmentCount = 20

        SentrySDKInternal.setStart(with: Options())

        for _ in 0..<10 {
            concurrentQueue.async {
                SentrySDKInternal.currentHub().capture(message: "mess")
                SentrySDKInternal.setCurrentHub(nil)

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
