@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryCrashIntegrationTests: NotificationCenterTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryCrashIntegrationTests")
    
    private class Fixture {
        let dateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let hub: SentryHubInternal
        let client: TestClient!
        let options: Options
        let sentryCrash: TestSentryCrashWrapper
        let fileManager: TestFileManager

        init() throws {
            SentryDependencyContainer.sharedInstance().sysctlWrapper = TestSysctl()
            sentryCrash = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
            sentryCrash.internalActiveDurationSinceLastCrash = 5.0
            sentryCrash.internalCrashedLastLaunch = true
            
            options = Options()
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            options.tracesSampleRate = 1.0
            
            client = TestClient(options: options, fileManager: try SentryFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            ))
            hub = TestHub(client: client, andScope: nil)

            fileManager = try TestFileManager(
                options: options,
                dateProvider: dateProvider,
                dispatchQueueWrapper: dispatchQueueWrapper
            )

            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
        }
        
        var session: SentrySession {
            let session = SentrySession(releaseName: "1.0.0", distinctId: "some-id")
            session.incrementErrors()
            
            return session
        }
        
        func getSut() throws -> SentryCrashIntegration<MockCrashDependencies> {
            return try getSut(crashWrapper: sentryCrash)
        }

        func getSut(crashWrapper: SentryCrashWrapper, fileManager: SentryFileManager? = nil, options: Options? = nil) throws -> SentryCrashIntegration<MockCrashDependencies> {
            let mockedDependencies = MockCrashDependencies(crashWrapper: crashWrapper, dispatchQueueWrapper: dispatchQueueWrapper, fileManager: fileManager)
            return try XCTUnwrap(SentryCrashIntegration(with: options ?? self.options, dependencies: mockedDependencies))
        }

        var sutWithoutCrash: SentryCrashIntegration<MockCrashDependencies>? {
            let crash = sentryCrash
            crash.internalCrashedLastLaunch = false
            let mockedDependencies = MockCrashDependencies(crashWrapper: crash, dispatchQueueWrapper: dispatchQueueWrapper)
            return SentryCrashIntegration(with: options, dependencies: mockedDependencies)
        }
    }

    private var fixture: Fixture!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        
        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAppState()
        fixture.client.fileManager.deleteAppState()
        fixture.client.fileManager.deleteAppHangEvent()
        
        SentrySDK.setStart(with: fixture.options)
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAbnormalSession()
        fixture.client.fileManager.deleteAppState()
        fixture.client.fileManager.deleteAppHangEvent()
        
        clearTestState()
    }
    
    // Test for GH-581
    func testReleaseNamePassedToSentryCrash() throws {
        let releaseName = "1.0.0"
        let dist = "14G60"
        // The start of the SDK installs all integrations
        SentrySDK.start { options in
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.releaseName = releaseName
            options.dist = dist
            options.removeAllIntegrations()
            options.enableCrashHandler = true
        }
        
        // To test this properly we need SentryCrash and SentryCrashIntegration installed and registered on the current hub of the SDK.

        let userInfo = try XCTUnwrap(SentryDependencyContainer.sharedInstance().crashReporter.userInfo)
        assertUserInfoField(userInfo: userInfo, key: "release", expected: releaseName)
        assertUserInfoField(userInfo: userInfo, key: "dist", expected: dist)
    }
    
    func testContext_IsPassedToSentryCrash() throws {
        SentrySDK.start { options in
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.removeAllIntegrations()
            options.enableCrashHandler = true
        }
        
        let userInfo = try XCTUnwrap(SentryDependencyContainer.sharedInstance().crashReporter.userInfo)
        let context = userInfo["context"] as? [String: Any]
        
        assertContext(context: context)
    }
    
    func testEndSessionAsCrashed_WithCurrentSession() throws {
        let expectedCrashedSession = givenCrashedSession()
        SentrySDKInternal.setCurrentHub(fixture.hub)
        
        try advanceTime(bySeconds: 10)
        
        _ = try fixture.getSut()
        
        assertCrashedSessionStored(expected: expectedCrashedSession)
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testEndSessionAsCrashed_WhenOOM_WithCurrentSession() throws {
        givenOOMAppState()
        SentrySDKInternal.startInvocations = 1
        
        let expectedCrashedSession = givenCrashedSession()
        
        SentrySDKInternal.setCurrentHub(fixture.hub)
        try advanceTime(bySeconds: 10)
        
        _ = try XCTUnwrap(fixture.sutWithoutCrash)
        
        assertCrashedSessionStored(expected: expectedCrashedSession)
    }
    
    func testOutOfMemoryTrackingDisabled() throws {
        givenOOMAppState()
        
        let session = givenCurrentSession()
        
        _ = try XCTUnwrap(fixture.sutWithoutCrash)
        
        let options = fixture.options
        options.enableWatchdogTerminationTracking = false
        
        let fileManager = fixture.client.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    #endif

    func testEndSessionAsCrashed_NoClientSet() throws {
        let (_, _) = try givenSutWithGlobalHub()
        
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    func testEndSessionAsCrashed_NoCrashLastLaunch() throws {
        let session = givenCurrentSession()

        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        _ = try fixture.getSut(crashWrapper: sentryCrash)

        let fileManager = fixture.client.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }

    func testEndSessionAsCrashed_NoCurrentSession() throws {
        let (_, _) = try givenSutWithGlobalHub()
        
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    // Abnormal sessions only work when we the SDK can detect fatal app hang events. These only work on iOS, tvOS and macCatalyst
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testEndSessionAsAbnormal_NoHubBound() throws {
        // Arrange
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        
        // Act
        _ = try fixture.getSut(crashWrapper: sentryCrash)
        
        // Assert
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    func testEndSessionAsAbnormal_NoCurrentSession() throws {
        // Arrange
        SentrySDKInternal.setCurrentHub(fixture.hub)
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        
        // Act
        _ = try fixture.getSut(crashWrapper: sentryCrash)
        
        // Assert
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    func testEndSessionAsAbnormal_NoAppHangEvent() throws {
        // Arrange
        SentrySDKInternal.setCurrentHub(fixture.hub)
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        
        let session = givenCurrentSession()
        
        // Act
        _ = try fixture.getSut(crashWrapper: sentryCrash)
        
        // Assert
        let fileManager = fixture.client.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    func testEndSessionAsAbnormal_AppHangEventDeletedInBetween() throws {
        // Arrange
        let fileManager = try DeleteAppHangWhenCheckingExistenceFileManager(
            options: fixture.options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: fixture.dispatchQueueWrapper
        )
        fixture.client.fileManager = fileManager
        
        SentrySDKInternal.setCurrentHub(fixture.hub)
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        
        let session = givenCurrentSession()
        let appHangEvent = Event()
        fileManager.storeAppHang(appHangEvent)

        // Act
        _ = try fixture.getSut(crashWrapper: sentryCrash, fileManager: fileManager)
        
        // Assert
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
    func testEndSessionAsAbnormal_AppHangEvent_EndsSessionAsAbnormal() throws {
        // Arrange
        SentrySDKInternal.setCurrentHub(fixture.hub)
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        
        let session = givenCurrentSession()
        
        let fileManager = fixture.client.fileManager
        let appHangEvent = Event()
        fileManager.storeAppHang(appHangEvent)
        
        // Act
        _ = try fixture.getSut(crashWrapper: sentryCrash)
        
        // Assert
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
        
        let actualSession = try XCTUnwrap(fileManager.readAbnormalSession())
        
        XCTAssertEqual(SentrySessionStatus.abnormal, actualSession.status)
        XCTAssertEqual(session.started.timeIntervalSince1970, actualSession.started.timeIntervalSince1970, accuracy: 0.001)
        
        let appHangEventTimestamp = try XCTUnwrap(appHangEvent.timestamp)
        let sessionEndTimestamp = try XCTUnwrap(actualSession.timestamp)
        XCTAssertEqual(appHangEventTimestamp.timeIntervalSince1970, sessionEndTimestamp.timeIntervalSince1970, accuracy: 0.001)
    }
    
    func testEndSessionAsAbnormal_AppHangEventAndCrash_EndsSessionAsCrashed() throws {
        // Arrange
        let expectedCrashedSession = givenCrashedSession()
        SentrySDKInternal.setCurrentHub(fixture.hub)
        let fileManager = fixture.client.fileManager
        let appHangEvent = Event()
        fileManager.storeAppHang(appHangEvent)
        
        try advanceTime(bySeconds: 10)
        
        // Act
        _ = try fixture.getSut()
        
        // Assert
        assertCrashedSessionStored(expected: expectedCrashedSession)
        XCTAssertNil(fileManager.readAbnormalSession())
    }
    
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            
    func testUninstall_DoesNotUpdateLocale_OnLocaleDidChangeNotification() throws {
        let (sut, hub) = try givenSutWithGlobalHubAndCrashWrapper()

        let locale = "garbage"
        setLocaleToGlobalScope(locale: locale)
        
        sut.uninstall()
        
        localeDidChange()
        
        assertLocaleOnHub(locale: locale, hub: hub)
    }
    
    func testOSCorrectlySetToScopeContext() throws {
        let (_, hub) = try givenSutWithGlobalHubAndCrashWrapper()
        
        assertContext(context: hub.scope.contextDictionary as? [String: Any] ?? ["": ""])
    }
    
    func testLocaleChanged_NoDeviceContext_SetsCurrentLocale() throws {
        let (sut, hub) = try givenSutWithGlobalHub()
        defer {
            sut.uninstall()
        }
        
        SentrySDK.configureScope { scope in
            scope.removeContext(key: "device")
        }
        
        localeDidChange()
        
        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }
    
    func testLocaleChanged_DifferentLocale_SetsCurrentLocale() throws {
        let (sut, hub) = try givenSutWithGlobalHubAndCrashWrapper()
        defer {
            sut.uninstall()
        }
        
        setLocaleToGlobalScope(locale: "garbage")
        
        localeDidChange()
        
        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }

    func testStartUpCrash_CallsFlush() throws {
        let (sut, hub) = try givenSutWithGlobalHubAndCrashWrapper()
        
        // Manually reset and enable the crash state because tearing down the global state in SentryCrash to achieve the same is complicated and doesn't really work.
        let crashStatePath = String(cString: sentrycrashstate_filePath())
        let api = sentrycrashcm_appstate_getAPI()
        sentrycrashstate_initialize(crashStatePath)
        api?.pointee.setEnabled(true)
        
        let transport = TestTransport()
        let client = SentryClientInternal(options: fixture.options, fileManager: fixture.fileManager)
        Dynamic(client).transportAdapter = TestTransportAdapter(transports: [transport], options: fixture.options)
        hub.bindClient(client)
        
        delayNonBlocking(timeout: 0.01)
        
        // Manually simulate a crash
        sentrycrashstate_notifyAppCrash()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-1")
        
        // Force reloading of crash state
        sentrycrashstate_initialize(sentrycrashstate_filePath())
        // Force sending all reports, because the crash reports are only sent once after first init.
        sut.sendAllSentryCrashReports()
        
        XCTAssertEqual(1, transport.flushInvocations.count)
        XCTAssertEqual(5.0, transport.flushInvocations.first)
        
        // Reset and disable crash state
        sentrycrashstate_reset()
        api?.pointee.setEnabled(false)
    }
    
#if os(macOS)
    
    func testUncaughtExceptions_Enabled() throws {
        defer { resetUserDefaults() }

        let options = Options()
        options.enableUncaughtNSExceptionReporting = true
        options.enableSwizzling = true
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "NSApplicationCrashOnExceptions"))
        // We have to set the flat to false, cause otherwise we would crash
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        NSApplication.shared.reportException(uncaughtInternalInconsistencyException)
        XCTAssertTrue(wasUncaughtExceptionHandlerCalled)
    }

    func testUncaughtExceptions_Enabled_ButSwizzlingDisabled() throws {
        defer { resetUserDefaults() }

        let options = Options()
        options.enableUncaughtNSExceptionReporting = true
        options.enableSwizzling = false
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "NSApplicationCrashOnExceptions"))

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        NSApplication.shared.reportException(uncaughtInternalInconsistencyException)
        XCTAssertFalse(wasUncaughtExceptionHandlerCalled)
    }

    func testUncaughtExceptions_Disabled() throws {
        defer { resetUserDefaults() }

        let options = Options()
        options.enableUncaughtNSExceptionReporting = false
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "NSApplicationCrashOnExceptions"))

        let crashReporter = SentryDependencyContainer.sharedInstance().crashReporter

        defer {
            crashReporter.uncaughtExceptionHandler = nil
            wasUncaughtExceptionHandlerCalled = false
        }
        crashReporter.uncaughtExceptionHandler = uncaughtExceptionHandler

        NSApplication.shared.reportException(uncaughtInternalInconsistencyException)
        XCTAssertFalse(wasUncaughtExceptionHandlerCalled)
    }
#endif // os(macOS)

    func testEnableCppExceptionsV2_SwapsCxaThrow() throws {
        // Arrange
        defer { sentrycrashct_unswap_cxa_throw() }

        let options = Options()
        options.experimental.enableUnhandledCPPExceptionsV2 = true
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        // Assert
        XCTAssertTrue(sentrycrashct_is_cxa_throw_swapped(), "C++ exception throw handler must be swapped when enableUnhandledCPPExceptionsV2 is true.")
    }

    func testCppExceptionsV2NotEnabled_DoesNotSwapCxaThrow() throws {
        // Arrange
        defer { sentrycrashct_unswap_cxa_throw() }

        let options = Options()
        options.experimental.enableUnhandledCPPExceptionsV2 = false
        options.enableCrashHandler = true

        // Act
        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        // Assert
        XCTAssertFalse(sentrycrashct_is_cxa_throw_swapped(), "C++ exception throw handler must NOT be swapped when enableUnhandledCPPExceptionsV2 is false.")
    }

    func testEnableTracingForCrashes_SetsCallback() throws {
        let options = Options()
        options.enablePersistingTracesWhenCrashing = true
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        XCTAssertTrue(sentrycrash_hasSaveTransaction())
    }

    func testEnableTracingForCrashes_Uninstall_RemovesCallback() throws {
        let options = Options()
        options.enablePersistingTracesWhenCrashing = true
        options.enableCrashHandler = true

        let (sut, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        sut.uninstall()

        XCTAssertFalse(sentrycrash_hasSaveTransaction())
    }

    func testEnableTracingForCrashes_Disabled_DoesNotSetCallback() throws {
        let options = Options()
        options.enablePersistingTracesWhenCrashing = false
        options.enableCrashHandler = true

        let (_, _) = try givenSutWithGlobalHubAndCrashWrapper(options)

        XCTAssertFalse(sentrycrash_hasSaveTransaction())
    }
    
    func testEnableTracingForCrashes_InvokeCallback_StoresTransaction() throws {
        let options = fixture.options
        options.enablePersistingTracesWhenCrashing = true
        
        let client = SentryClientInternal(options: options)
        defer { client?.fileManager.deleteAllEnvelopes() }
        let hub = SentryHubInternal(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        
        _ = try fixture.getSut(crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper)
        
        let transaction = SentrySDK.startTransaction(name: "Crashing", operation: "Operation", bindToScope: true)
        
        sentrycrash_invokeSaveTransaction()
        
        XCTAssertTrue(transaction.isFinished)
        
        XCTAssertEqual(1, client?.fileManager.getAllEnvelopes().count)
        let transactionEnvelopeFileContents = try XCTUnwrap(client?.fileManager.getOldestEnvelope())
        let envelope = try XCTUnwrap(SentrySerializationSwift.envelope(with: transactionEnvelopeFileContents.contents))
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("transaction", envelope.items.first?.header.type)
    }
    
    func testEnableTracingForCrashes_InvokeCallbackWhenNoSpanOnScope_TransactionNotFinished() throws {
        let options = fixture.options
        options.enablePersistingTracesWhenCrashing = true
        
        let client = SentryClientInternal(options: options)
        defer { client?.fileManager.deleteAllEnvelopes() }
        let hub = SentryHubInternal(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        
        _ = try fixture.getSut(crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper)
        
        let transaction = SentrySDK.startTransaction(name: "name", operation: "operation", bindToScope: true)
        SentrySDKInternal.currentHub().scope.span = nil
        
        sentrycrash_invokeSaveTransaction()
        
        XCTAssertFalse(transaction.isFinished)
        XCTAssertEqual(0, client?.fileManager.getAllEnvelopes().count)
    }
    
    func testEnableTracingForCrashes_InvokeCallback_WhenSpanOnScopeIsNotATracer_StoresTransaction() throws {
        let options = fixture.options
        options.enablePersistingTracesWhenCrashing = true
        
        let client = SentryClientInternal(options: options)
        defer { client?.fileManager.deleteAllEnvelopes() }
        let hub = SentryHubInternal(client: client, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        
        _ = try fixture.getSut(crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper)
        
        let transaction = SentrySDK.startTransaction(name: "name", operation: "operation", bindToScope: true)
        let span = transaction.startChild(operation: "child")
        SentrySDKInternal.currentHub().scope.span = span
        
        sentrycrash_invokeSaveTransaction()
        
        XCTAssertEqual(1, client?.fileManager.getAllEnvelopes().count)
        let transactionEnvelopeFileContents = try XCTUnwrap(client?.fileManager.getOldestEnvelope())
        let envelope = try XCTUnwrap(SentrySerializationSwift.envelope(with: transactionEnvelopeFileContents.contents))
        XCTAssertEqual(1, envelope.items.count)
        XCTAssertEqual("transaction", envelope.items.first?.header.type)
    }
    
    func testAttributesAreNotPassedToSentryCrash() throws {
        // Start the SDK without any integration
        SentrySDK.start { options in
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.removeAllIntegrations()
        }
        
        // Configure some attributes
        SentrySDK.configureScope { scope in
            scope.setAttribute(value: "value", key: "key")
            scope.setEnvironment("test-attributes")
        }
        
        // UserInfo is set when installing the integration, so let's manually install it again to use the new scope values
        _ = try fixture.getSut()
        
        let userInfo = try XCTUnwrap(SentryDependencyContainer.sharedInstance().crashReporter.userInfo)
        // Double check the environment just set is in the user info
        assertUserInfoField(userInfo: userInfo, key: "environment", expected: "test-attributes")
        // Validate there is no attributes in the user info
        XCTAssertNil(userInfo["attributes"])
    }
    
    private func givenCurrentSession() -> SentrySession {
        // serialize sets the timestamp
        let session = SentrySession(jsonObject: fixture.session.serialize())!
        fixture.client.fileManager.storeCurrentSession(session)
        return session
    }
    
    private func givenCrashedSession() -> SentrySession {
        let session = givenCurrentSession()
        session.endCrashed(withTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(5))
        
        return session
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private func givenOOMAppState() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: UIDevice.current.identifierForVendor?.uuidString ?? "", isDebugging: false, systemBootTimestamp: SentryDependencyContainer.sharedInstance().dateProvider.date())
        appState.isActive = true
        fixture.client.fileManager.store(appState)
        fixture.client.fileManager.moveAppStateToPreviousAppState()
    }
    #endif
    
    private func givenSutWithGlobalHub() throws -> (SentryCrashIntegration<MockCrashDependencies>, SentryHubInternal) {
        let sut = try XCTUnwrap(fixture.getSut())
        let hub = fixture.hub
        SentrySDKInternal.setCurrentHub(hub)

        return (sut, hub)
    }
    
    private func givenSutWithGlobalHubAndCrashWrapper(_ options: Options? = nil) throws -> (SentryCrashIntegration<MockCrashDependencies>, SentryHubInternal) {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        SentryDependencyContainer.sharedInstance().uiDeviceWrapper.start()
#endif
        let sut = try fixture.getSut(crashWrapper: SentryDependencyContainer.sharedInstance().crashWrapper, options: options)
        let hub = fixture.hub
        SentrySDKInternal.setCurrentHub(hub)

        return (sut, hub)
    }
    
    private func setLocaleToGlobalScope(locale: String) {
        SentrySDK.configureScope { scope in
            guard var device = scope.contextDictionary["device"] as? [String: Any] else {
                XCTFail("No device found on context.")
                return
            }
            
            device["locale"] = locale
            scope.setContext(value: device, key: "device")
        }
    }
    
    private func assertUserInfoField(userInfo: [AnyHashable: Any], key: String, expected: String) {
        if let actual = userInfo[key] as? String {
            XCTAssertEqual(expected, actual)
        } else {
            XCTFail("\(key) not passed to SentryCrash.userInfo")
        }
    }
    
    private func assertCrashedSessionStored(expected: SentrySession) {
        let crashedSession = fixture.client.fileManager.readCrashedSession()
        XCTAssertEqual(SentrySessionStatus.crashed, crashedSession?.status)
        XCTAssertEqual(expected, crashedSession)
        XCTAssertNil(fixture.client.fileManager.readCurrentSession())
    }
    
    private func assertContext(context: [String: Any]?) {
        guard let os = context?["os"] as? [String: Any] else {
            XCTFail("No OS found on context.")
            return
        }
        
        guard let device = context?["device"] as? [String: Any] else {
            XCTFail("No device found on context.")
            return
        }
        
        #if targetEnvironment(macCatalyst) || os(macOS)
        XCTAssertEqual("macOS", device["family"] as? String)
        XCTAssertEqual("macOS", os["name"] as? String)
        
        let osVersion = ProcessInfo().operatingSystemVersion
        XCTAssertEqual("\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)", os["version"] as? String)
        #elseif os(iOS)
        XCTAssertEqual("iOS", device["family"] as? String)
        XCTAssertEqual("iOS", os["name"] as? String)
        XCTAssertEqual(UIDevice.current.systemVersion, os["version"] as? String)
        #elseif os(tvOS)
        XCTAssertEqual("tvOS", device["family"] as? String)
        XCTAssertEqual("tvOS", os["name"] as? String)
        XCTAssertEqual(UIDevice.current.systemVersion, os["version"] as? String)
        #endif
        
        XCTAssertEqual(Locale.autoupdatingCurrent.identifier, device["locale"] as? String)
    }
    
    private func assertLocaleOnHub(locale: String, hub: SentryHubInternal) {
        let context = hub.scope.contextDictionary as? [String: Any] ?? ["": ""]
        
        guard let device = context["device"] as? [String: Any] else {
            XCTFail("No device found on context.")
            return
        }
        
        XCTAssertEqual(locale, device["locale"] as? String)
    }
    
    private func advanceTime(bySeconds: TimeInterval) throws {
        try XCTUnwrap(SentryDependencyContainer.sharedInstance().dateProvider as? TestCurrentDateProvider).setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}

private class DeleteAppHangWhenCheckingExistenceFileManager: SentryFileManager {
    
    public init(options: Options?, dateProvider: any SentryCurrentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper) throws {
        let helper = try SentryFileManagerHelper(options: options)
        super.init(helper: helper, dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper)
    }
    
    override func appHangEventExists() -> Bool {
        let result = super.appHangEventExists()
        self.deleteAppHangEvent()
        return result
    }
}

class MockCrashDependencies: CrashIntegrationProvider {

    let mockedCrashWrapper: SentryCrashWrapper
    let mockedDispatchQueueWrapper: SentryDispatchQueueWrapper
    let mockedFileManager: SentryFileManager?

    init(crashWrapper: SentryCrashWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper, fileManager: SentryFileManager? = nil) {
        self.mockedCrashWrapper = crashWrapper
        self.mockedDispatchQueueWrapper = dispatchQueueWrapper
        self.mockedFileManager = fileManager
    }

    var appStateManager: Sentry.SentryAppStateManager {
        SentryDependencyContainer.sharedInstance().appStateManager
    }

    var crashWrapper: Sentry.SentryCrashWrapper {
        mockedCrashWrapper
    }

    var fileManager: Sentry.SentryFileManager? {
        mockedFileManager ?? SentryDependencyContainer.sharedInstance().fileManager
    }

    var dispatchQueueWrapper: Sentry.SentryDispatchQueueWrapper {
        mockedDispatchQueueWrapper
    }
    
    func getCrashIntegrationSessionBuilder(_ options: Sentry.Options) -> Sentry.SentryCrashIntegrationSessionHandler? {
        guard let fileManager else {
            return nil
        }
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        let watchdogLogic = SentryWatchdogTerminationLogic(options: options,
                                                   crashAdapter: crashWrapper,
                                                   appStateManager: appStateManager)
        return SentryCrashIntegrationSessionHandler(
            crashWrapper: crashWrapper,
            watchdogTerminationLogic: watchdogLogic,
            fileManager: fileManager
        )
#else
            return SentryCrashIntegrationSessionHandler(crashWrapper: crashWrapper, fileManager: fileManager)
#endif
    }
    
    var crashReporter: Sentry.SentryCrashSwift {
        SentryDependencyContainer.sharedInstance().crashReporter
    }
    
    func getCrashInstallationReporter(_ options: Options) -> SentryCrashInstallationReporter {
        let inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)

        return SentryCrashInstallationReporter(
            inAppLogic: inAppLogic,
            crashWrapper: crashWrapper,
            dispatchQueue: dispatchQueueWrapper
        )
    }
}
