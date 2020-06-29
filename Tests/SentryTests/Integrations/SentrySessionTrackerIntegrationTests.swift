@testable import Sentry
import XCTest

class SentrySessionTrackerIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        
        do {
            let dsn = try SentryDsn(string: "https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394")
            let fileManager = try SentryFileManager(dsn: dsn)
            
            fileManager.deleteCurrentSession()
            fileManager.deleteTimestampLastInForeground()
        } catch {
            XCTFail("Could not delete session data")
        }
        
        
    }

    func testWithNotifications()  {
        startSdk()
        
        for _ in Array(0...9) {
            SentryInstallation.reset()
            // Send healthy session
            willResignActive()
            delayNonBlocking()
            
            // sends one healthy session
            didBecomeActive()
            delayNonBlocking()
            
            // increment error count
            SentrySDK.capture(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"]))
            willResignActive()
            delayNonBlocking()
            
            // sends one errored session
            didBecomeActive()
            delayNonBlocking()
        }
        
        delayNonBlocking()
    }

    private func startSdk() {
        SentrySDK.start { options in
            options.dsn = "https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394"
            
            options.releaseName = "philipp test 10"
            options.debug = true
            options.logLevel = SentryLogLevel.debug
            
            options.sessionTrackingIntervalMillis = 1
            options.enableAutoSessionTracking = true
        }
    }
    
    
    private func willTerminate() {
        NotificationCenter.default.post(Notification(name: UIApplication.willTerminateNotification))
    }

    private func didBecomeActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.didBecomeActiveNotification))
    }

    private func willResignActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.willResignActiveNotification))
    }
    
    private func delayNonBlocking(timeout: Double = 0.5) {
        let group = DispatchGroup()
        group.enter()
        let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
        
        queue.asyncAfter(deadline: .now() + timeout) {
            group.leave()
        }
        
        group.wait()
    }
}
