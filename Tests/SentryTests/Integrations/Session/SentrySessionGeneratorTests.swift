@testable import Sentry
import SentryTestUtils
import XCTest

/**
* This isn't an actual test. It sends Sessions to the Sentry, but doesn't verify if they arrive there.
*/
@available(OSX 10.10, *)
class SentrySessionGeneratorTests: NotificationCenterTestCase {
    
    struct Sessions {
        var healthy = 0
        var errored = 0
        var crashed = 0
        var oom = 0
        var abnormal = 0
    }
    
    private var sentryCrash: TestSentryCrashWrapper!
    private var autoSessionTrackingIntegration: SentryAutoSessionTrackingIntegration!
    private var crashIntegration: SentryCrashIntegration!
    private var options: Options!
    private var fileManager: SentryFileManager!
    
    override func setUp() {
        super.setUp()
        
        options = Options.noIntegrations()
        options.dsn = TestConstants.realDSN
        
        options.releaseName = "Release Health"
        options.debug = true
        
        options.sessionTrackingIntervalMillis = 1
        
        // We want to start and stop the SentryAutoSessionTrackingIntegration ourselves so we can send crashed and abnormal sessions.
        options.integrations = Options.defaultIntegrations().filter { (name) -> Bool in
            return name != "SentryAutoSessionTrackingIntegration"
        }

        fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        
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
        autoSessionTrackingIntegration.stop()
    }
    
    /**
     * Disabled on purpose. This test just sends sessions to Sentry, but doesn't verify that they arrive there properly.
     */
    func testSendSessions() {
        sendSessions(amount: Sessions(healthy: 10, errored: 10, crashed: 3, oom: 1, abnormal: 1))
    }
    
    private func sendSessions(amount: Sessions ) {
        startSdk()
        
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
            crashIntegration.install(with: options)
            autoSessionTrackingIntegration.stop()
            autoSessionTrackingIntegration.install(with: options)
            goToForeground()
            
            // Almost always the AutoSessionTrackingIntegration is faster
            // than the SentryCrashIntegration creating the event from the
            // crash report on a background thread.
            let crashEvent = Event()
            crashEvent.level = SentryLevel.fatal
            crashEvent.message = SentryMessage(formatted: "Crash for SentrySessionGeneratorTests")
            SentrySDK.captureCrash(crashEvent)
        }
        sentryCrash.internalCrashedLastLaunch = false
        
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let appState = SentryAppState(releaseName: options.releaseName!, osVersion: UIDevice.current.systemVersion, vendorId: "12345678-1234-1234-1234-1234567890AB", isDebugging: false, systemBootTimestamp: Date())
        appState.isActive = true
        fileManager.store(appState)
        
        for _ in Array(1...amount.oom) {
            // send crashed session
            crashIntegration.install(with: options)
            
            autoSessionTrackingIntegration.stop()
            autoSessionTrackingIntegration.install(with: options)
            goToForeground()
            
            SentrySDK.captureCrash(TestData.oomEvent)
        }
        fileManager.deleteAppState()
        #endif
        
        for _ in Array(1...amount.abnormal) {
            autoSessionTrackingIntegration.stop()
            autoSessionTrackingIntegration.install(with: options)
            goToForeground()
        }
        
        // close current session
        terminateApp()
        
        // Wait 5 seconds to send all sessions
        delayNonBlocking(timeout: 5)
    }
    
    private func startSdk() {
        
        SentrySDK.start(options: options)
        
        sentryCrash = TestSentryCrashWrapper.sharedInstance()
        let client = SentrySDK.currentHub().getClient()
        let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: self.sentryCrash, andDispatchQueue: SentryDispatchQueueWrapper())
        SentrySDK.setCurrentHub(hub)
        
        crashIntegration = SentryCrashIntegration(crashAdapter: sentryCrash, andDispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        crashIntegration.install(with: options)
        
        autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration()
        autoSessionTrackingIntegration.install(with: options)
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
