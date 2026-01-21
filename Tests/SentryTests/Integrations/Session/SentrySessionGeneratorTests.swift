@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

/**
* This isn't an actual test. It sends Sessions to the Sentry, but doesn't verify if they arrive there.
*/
class SentrySessionGeneratorTests: NotificationCenterTestCase {
    
    struct Sessions {
        var healthy = 0
        var errored = 0
        var crashed = 0
        var oom = 0
        var abnormal = 0
    }
    
    private var sentryCrash: TestSentryCrashWrapper!
    private var autoSessionTrackingIntegration: SentryAutoSessionTrackingIntegration<SentryDependencyContainer>!
    private var crashIntegration: SentryCrashIntegration<MockCrashDependencies>!
    private var mockedCrashDependencies: MockCrashDependencies!
    private var options: Options!
    private var fileManager: SentryFileManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()

        options = Options()
        options.dsn = TestConstants.realDSN
        
        options.releaseName = "Release Health"
        options.debug = true
        
        options.sessionTrackingIntervalMillis = 1
        
        // We want to start and stop the SentryAutoSessionTrackingIntegration ourselves so we can send crashed and abnormal sessions.
        options.enableAutoSessionTracking = false

        fileManager = try XCTUnwrap(SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
        ))

        fileManager.deleteCurrentSession()
        fileManager.deleteCrashedSession()
        fileManager.deleteTimestampLastInForeground()
        fileManager.deleteAppState()
    }
    
    override func tearDown() {
        super.tearDown()
        
        fileManager.deleteCurrentSession()
        fileManager.deleteCrashedSession()
        fileManager.deleteTimestampLastInForeground()
        fileManager.deleteAppState()
        autoSessionTrackingIntegration.uninstall()
    }
    
    /**
     * Disabled on purpose. This test just sends sessions to Sentry, but doesn't verify that they arrive there properly.
     */
    func testSendSessions() throws {
        try sendSessions(amount: Sessions(healthy: 10, errored: 10, crashed: 3, oom: 1, abnormal: 1))
    }
    
    private func sendSessions(amount: Sessions ) throws {
        try startSdk()
        
        goToForeground()
        // On healthy session will be sent at the end
        for _ in Array(1...amount.healthy - 1) {
            // Send healthy session
            goToBackground()
            goToForeground()
            // now healthy session is sent
            
            //new session starts
        }
        
        for i in Array(1...amount.errored) {
            // increment error count
            // We use the current date for the error message to generate new
            // issues for the release.
            SentrySDK.capture(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Error \(i) for \(Date())"]))
            goToBackground()
            goToForeground()
            // sends one errored session
        }
        
        sentryCrash.internalCrashedLastLaunch = true
        for _ in Array(1...amount.crashed) {
            // send crashed session
            crashIntegration = try XCTUnwrap(SentryCrashIntegration(with: options, dependencies: mockedCrashDependencies))
            autoSessionTrackingIntegration.uninstall()
            autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
            goToForeground()
            
            // Almost always the AutoSessionTrackingIntegration is faster
            // than the SentryCrashIntegration creating the event from the
            // crash report on a background thread.
            let fatalEvent = Event()
            fatalEvent.level = SentryLevel.fatal
            fatalEvent.message = SentryMessage(formatted: "Crash for SentrySessionGeneratorTests")
            SentrySDKInternal.captureFatalEvent(fatalEvent)
        }
        sentryCrash.internalCrashedLastLaunch = false
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let appState = SentryAppState(releaseName: options.releaseName!, osVersion: UIDevice.current.systemVersion, vendorId: "12345678-1234-1234-1234-1234567890AB", isDebugging: false, systemBootTimestamp: Date())
        appState.isActive = true
        fileManager.store(appState)
        
        for _ in Array(1...amount.oom) {
            // send crashed session
            crashIntegration = try XCTUnwrap(SentryCrashIntegration(with: options, dependencies: mockedCrashDependencies))
            
            autoSessionTrackingIntegration.uninstall()
            autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
            goToForeground()
            
            SentrySDKInternal.captureFatalEvent(TestData.oomEvent)
        }
        fileManager.deleteAppState()
        #endif
        
        for _ in Array(1...amount.abnormal) {
            autoSessionTrackingIntegration.uninstall()
            autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
            goToForeground()
        }
        
        // close current session
        terminateApp()
        
        // Wait 5 seconds to send all sessions
        delayNonBlocking(timeout: 5)
    }
    
    private func startSdk() throws {
        
        SentrySDK.start(options: options)
        
        sentryCrash = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        let client = SentrySDKInternal.currentHub().getClient()
        let hub = SentryHubInternal(client: client, andScope: nil, andCrashWrapper: self.sentryCrash, andDispatchQueue: SentryDispatchQueueWrapper())
        SentrySDKInternal.setCurrentHub(hub)
        
        mockedCrashDependencies = MockCrashDependencies(crashWrapper: sentryCrash, dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), fileManager: fileManager)
        crashIntegration = try XCTUnwrap(SentryCrashIntegration(with: options, dependencies: mockedCrashDependencies))
        
        // We need to enable auto session tracking in options or SentryAutoSessionTrackingIntegration's init will return nil
        options.enableAutoSessionTracking = true
        autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())
    }
    
    private func goToForeground(forSeconds: TimeInterval = 0.2) {
        willEnterForeground()
        didBecomeActive()
        delayNonBlocking(timeout: forSeconds)
    }
    
    private func goToBackground(forSeconds: TimeInterval = 0.2) {
        willResignActive()
        didEnterBackground()
        delayNonBlocking(timeout: forSeconds)
    }
}
