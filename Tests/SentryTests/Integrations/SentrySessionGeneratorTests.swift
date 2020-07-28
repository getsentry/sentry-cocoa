@testable import Sentry
import XCTest

/**
* This isn't an actual test. It sends Sessions to the Sentry, but doesn't verify if they arrive there.
*/
@available(OSX 10.10, *)
class SentrySessionGeneratorTests: XCTestCase {
    
    struct Sessions {
        var healthy = 0
        var errored = 0
        var crashed = 0
        var abnormal = 0
    }
    
    private let dsnAsString = "https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394"
    
    private var sentryCrash: TestSentryCrashWrapper!
    private var autoSessionTrackingIntegration: SentryAutoSessionTrackingIntegration!
    private var options: Options!
    
    override func setUp() {
        super.setUp()
        
        do {
            let dsn = try SentryDsn(string: dsnAsString)
            let fileManager = try SentryFileManager(dsn: dsn, with: TestCurrentDateProvider())
            
            fileManager.deleteCurrentSession()
            fileManager.deleteTimestampLastInForeground()
        } catch {
            XCTFail("Could not delete session data")
        }
    }
    
    /**
     * Disabled on purpose. This test just sends sessions to Sentry, but doesn't verify that they arrive there properly.
     */
    func tesSendSessions() {
        sendSessions(amount: Sessions(healthy: 10, errored: 10, crashed: 1, abnormal: 1))
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
            autoSessionTrackingIntegration.stop()
            autoSessionTrackingIntegration.install(with: options)
            goToForeground()
        }
        sentryCrash.internalCrashedLastLaunch = false
        
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
        options = Options()
        options.dsn = self.dsnAsString
        
        options.releaseName = "Release Health"
        options.debug = true
        options.logLevel = SentryLogLevel.debug
        
        options.sessionTrackingIntervalMillis = 1
        options.enableAutoSessionTracking = true
        
        // We want to start and stop the SentryAutoSessionTrackingIntegration ourselves so we can send crashed and abnormal sessions.
        options.integrations = Options.defaultIntegrations().filter { (name) -> Bool in
            return name != "SentryAutoSessionTrackingIntegration"
        }
        
        SentrySDK.start(options: options)
        
        sentryCrash = TestSentryCrashWrapper()
        let client = SentrySDK.currentHub().getClient()
        let hub = SentryHub(client: client, andScope: nil, andSentryCrashWrapper: self.sentryCrash)
        SentrySDK.setCurrentHub(hub)
        
        autoSessionTrackingIntegration = SentryAutoSessionTrackingIntegration()
        autoSessionTrackingIntegration.install(with: options)
    }
    
    private func goToForeground(forSeconds: TimeInterval = 0.2) {
        TestNotificationCenter.willEnterForeground()
        TestNotificationCenter.didBecomeActive()
        delayNonBlocking(timeout: forSeconds)
    }
    
    private func goToBackground(forSeconds: TimeInterval = 0.2) {
        TestNotificationCenter.willResignActive()
        TestNotificationCenter.didEnterBackground()
        delayNonBlocking(timeout: forSeconds)
    }
    
    private func terminateApp() {
        TestNotificationCenter.willTerminate()
    }
}
