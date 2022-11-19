import XCTest

class SentryCrashIntegrationTests: NotificationCenterTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryCrashIntegrationTests")
    private static let dsn = TestConstants.dsn(username: "SentryCrashIntegrationTests")
    
    private class Fixture {
        
        let currentDateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let hub: SentryHub
        let client: TestClient
        let options: Options
        let sentryCrash: TestSentryCrashWrapper
        
        init() {
            sentryCrash = TestSentryCrashWrapper.sharedInstance()
            sentryCrash.internalActiveDurationSinceLastCrash = 5.0
            sentryCrash.internalCrashedLastLaunch = true
            
            options = Options()
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            client = TestClient(options: options)
            hub = TestHub(client: client, andScope: nil)
        }
        
        var session: SentrySession {
            let session = SentrySession(releaseName: "1.0.0")
            session.incrementErrors()
            
            return session
        }
        
        func getSut() -> SentryCrashIntegration {
            return getSut(crashWrapper: sentryCrash)
        }
        
        func getSut(crashWrapper: SentryCrashWrapper) -> SentryCrashIntegration {
            return SentryCrashIntegration(crashAdapter: crashWrapper, andDispatchQueueWrapper: dispatchQueueWrapper)
        }
        
        var sutWithoutCrash: SentryCrashIntegration {
            let crash = sentryCrash
            crash.internalCrashedLastLaunch = false
            return SentryCrashIntegration(crashAdapter: crash, andDispatchQueueWrapper: dispatchQueueWrapper)
        }
    }
    
    private let fixture = Fixture()
    
    override func setUp() {
        super.setUp()
        CurrentDate.setCurrentDateProvider(fixture.currentDateProvider)
        
        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAppState()
    }
    
    override func tearDown() {
        super.tearDown()
        fixture.client.fileManager.deleteCurrentSession()
        fixture.client.fileManager.deleteCrashedSession()
        fixture.client.fileManager.deleteAppState()
        
        clearTestState()
    }
    
    // Test for GH-581
    func testReleaseNamePassedToSentryCrash() {
        let releaseName = "1.0.0"
        let dist = "14G60"
        // The start of the SDK installs all integrations
        SentrySDK.start { options in
            options.dsn = SentryCrashIntegrationTests.dsnAsString
            options.releaseName = releaseName
            options.dist = dist
        }
        
        // To test this properly we need SentryCrash and SentryCrashIntegration installed and registered on the current hub of the SDK.
        
        let instance = SentryCrash.sharedInstance()
        let userInfo = (instance?.userInfo ?? ["": ""]) as Dictionary
        assertUserInfoField(userInfo: userInfo, key: "release", expected: releaseName)
        assertUserInfoField(userInfo: userInfo, key: "dist", expected: dist)
    }
    
    func testContext_IsPassedToSentryCrash() {
        SentrySDK.start { options in
            options.dsn = SentryCrashIntegrationTests.dsnAsString
        }
        
        let instance = SentryCrash.sharedInstance()
        let userInfo = (instance?.userInfo ?? ["": ""]) as Dictionary
        let context = userInfo["context"] as? [String: Any]
        
        assertContext(context: context)
    }
    
    func testSystemInfoIsEmpty() {
        let scope = Scope()
        SentryCrashIntegration.enrichScope(scope, crashWrapper: TestSentryCrashWrapper.sharedInstance())
        
        // We don't worry about the actual values
        // This is an edge case where the user doesn't use the
        // SentryCrashIntegration. Just make sure to not crash.
        XCTAssertFalse(scope.contextDictionary.allValues.isEmpty)
    }
    
    func testEndSessionAsCrashed_WithCurrentSession() {
        let expectedCrashedSession = givenCrashedSession()
        SentrySDK.setCurrentHub(fixture.hub)
        
        advanceTime(bySeconds: 10)
        
        let sut = fixture.getSut()
        sut.install(with: Options())
        
        assertCrashedSessionStored(expected: expectedCrashedSession)
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testEndSessionAsCrashed_WhenOOM_WithCurrentSession() {
        fixture.client.fileManager = try! SentryFileManager(options: fixture.options, andCurrentDateProvider: TestCurrentDateProvider())
        givenOOMAppState()
        SentrySDK.startInvocations = 1
        
        let expectedCrashedSession = givenCrashedSession()
        
        SentrySDK.setCurrentHub(fixture.hub)
        advanceTime(bySeconds: 10)
        
        let sut = fixture.sutWithoutCrash
        sut.install(with: fixture.options)
        
        assertCrashedSessionStored(expected: expectedCrashedSession)
    }
    
    func testOutOfMemoryTrackingDisabled() {
        givenOOMAppState()
        
        let session = givenCurrentSession()
        
        let sut = fixture.sutWithoutCrash
        let options = fixture.options
        options.enableOutOfMemoryTracking = false
        sut.install(with: options)
        
        let fileManager = fixture.client.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    #endif
    
    func testEndSessionAsCrashed_NoClientSet() {
        let (sut, _) = givenSutWithGlobalHub()
        
        sut.install(with: Options())
        
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    func testEndSessionAsCrashed_NoCrashLastLaunch() {
        let session = givenCurrentSession()
        
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        let sut = SentryCrashIntegration(crashAdapter: sentryCrash, andDispatchQueueWrapper: fixture.dispatchQueueWrapper)
        sut.install(with: Options())
        
        let fileManager = fixture.client.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    func testEndSessionAsCrashed_NoCurrentSession() {
        let (sut, _) = givenSutWithGlobalHub()
        
        sut.install(with: Options())
        
        let fileManager = fixture.client.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    func testInstall_WhenStitchAsyncCallsEnabled_CallsInstallAsyncHooks() {
        let sut = fixture.getSut()
        
        let options = Options()
        options.stitchAsyncCode = true
        sut.install(with: options)
        
        XCTAssertTrue(fixture.sentryCrash.installAsyncHooksCalled)
    }
    
    func testInstall_WhenStitchAsyncCallsDisabled_DoesNotCallInstallAsyncHooks() {
        fixture.getSut().install(with: Options())
        
        XCTAssertFalse(fixture.sentryCrash.installAsyncHooksCalled)
    }

    func testUninstall_CallsClose() {
        let sut = fixture.getSut()

        sut.install(with: Options())

        sut.uninstall()

        XCTAssertTrue(fixture.sentryCrash.closeCalled)
    }
    
    func testUninstall_DoesNotUpdateLocale_OnLocaleDidChangeNotification() {
        let (sut, hub) = givenSutWithGlobalHubAndCrashWrapper()

        sut.install(with: Options())

        let locale = "garbage"
        setLocaleToGlobalScope(locale: locale)
        
        sut.uninstall()
        
        localeDidChange()
        
        assertLocaleOnHub(locale: locale, hub: hub)
    }
    
    func testOSCorrectlySetToScopeContext() {
        let (sut, hub) = givenSutWithGlobalHubAndCrashWrapper()
        
        sut.install(with: Options())
        
        assertContext(context: hub.scope.contextDictionary as? [String: Any] ?? ["": ""])
    }
    
    func testLocaleChanged_NoDeviceContext_SetsCurrentLocale() {
        let (sut, hub) = givenSutWithGlobalHub()
        
        sut.install(with: Options())
        
        SentrySDK.configureScope { scope in
            scope.removeContext(key: "device")
        }
        
        localeDidChange()
        
        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }
    
    func testLocaleChanged_DifferentLocale_SetsCurrentLocale() {
        let (sut, hub) = givenSutWithGlobalHubAndCrashWrapper()
        
        sut.install(with: Options())
        
        setLocaleToGlobalScope(locale: "garbage")
        
        localeDidChange()
        
        assertLocaleOnHub(locale: Locale.autoupdatingCurrent.identifier, hub: hub)
    }

    // !!!: Disabled until flakiness can be fixed
    func testStartUpCrash_CallsFlush_disabled() throws {
        let (sut, hub) = givenSutWithGlobalHubAndCrashWrapper()
        sut.install(with: Options())
        
        // Manually reset and enable the crash state because tearing down the global state in SentryCrash to achieve the same is complicated and doesn't really work.
        let crashStatePath = String(cString: sentrycrashstate_filePath())
        let api = sentrycrashcm_appstate_getAPI()
        sentrycrashstate_initialize(crashStatePath)
        api?.pointee.setEnabled(true)
        
        let transport = TestTransport()
        let client = SentryClient(options: fixture.options)
        Dynamic(client).transportAdapter = TestTransportAdapter(transport: transport, options: fixture.options)
        hub.bindClient(client)
        
        delayNonBlocking(timeout: 0.01)
        
        // Manually simulate a crash
        sentrycrashstate_notifyAppCrash()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-1")
        
        // Force reloading of crash state
        sentrycrashstate_initialize(sentrycrashstate_filePath())
        // Force sending all reports, because the crash reports are only sent once after first init.
        SentryCrashIntegration.sendAllSentryCrashReports()
        
        XCTAssertEqual(1, transport.flushInvocations.count)
        XCTAssertEqual(5.0, transport.flushInvocations.first)
        
        // Reset and disable crash state
        sentrycrashstate_reset()
        api?.pointee.setEnabled(false)
    }
    
    private func givenCurrentSession() -> SentrySession {
        // serialize sets the timestamp
        let session = SentrySession(jsonObject: fixture.session.serialize())!
        fixture.client.fileManager.storeCurrentSession(session)
        return session
    }
    
    private func givenCrashedSession() -> SentrySession {
        let session = givenCurrentSession()
        session.endCrashed(withTimestamp: fixture.currentDateProvider.date().addingTimeInterval(5))
        
        return session
    }
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private func givenOOMAppState() {
        let appState = SentryAppState(releaseName: TestData.appState.releaseName, osVersion: UIDevice.current.systemVersion, vendorId: UIDevice.current.identifierForVendor?.uuidString ?? "", isDebugging: false, systemBootTimestamp: fixture.currentDateProvider.date())
        appState.isActive = true
        fixture.client.fileManager.store(appState)
        fixture.client.fileManager.moveAppStateToPreviousAppState()
    }
    #endif
    
    private func givenSutWithGlobalHub() -> (SentryCrashIntegration, SentryHub) {
        let sut = fixture.getSut()
        let hub = fixture.hub
        SentrySDK.setCurrentHub(hub)

        return (sut, hub)
    }
    
    private func givenSutWithGlobalHubAndCrashWrapper() -> (SentryCrashIntegration, SentryHub) {
        let sut = fixture.getSut(crashWrapper: SentryCrashWrapper.sharedInstance())
        let hub = fixture.hub
        SentrySDK.setCurrentHub(hub)

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
    
    private func assertLocaleOnHub(locale: String, hub: SentryHub) {
        let context = hub.scope.contextDictionary as? [String: Any] ?? ["": ""]
        
        guard let device = context["device"] as? [String: Any] else {
            XCTFail("No device found on context.")
            return
        }
        
        XCTAssertEqual(locale, device["locale"] as? String)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
}
