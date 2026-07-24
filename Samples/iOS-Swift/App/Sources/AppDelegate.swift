import SentrySampleShared
import UIKit

// swiftlint:disable force_cast force_try force_unwrapping
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var randomDistributionTimer: Timer?

    var args: [String] {
        ProcessInfo.processInfo.arguments
    }
    
    var env: [String: String] {
        ProcessInfo.processInfo.environment
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .apnsTokenReceived, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .apnsTokenReceived, object: nil)
        print("[iOS-Swift] Failed to register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("[iOS-Swift] [debug] launch arguments: \(args)")
        print("[iOS-Swift] [debug] launch environment: \(env)")

        if args.contains(SentrySDKOverrides.Special.wipeDataOnLaunch.rawValue) {
            removeAppData()
        }

        SentrySDKWrapper.spanCaptureHandler = { LaunchVCTransactionCapture.shared.capture($0) }

        // Workaround for the residual GH-8152 limitation (tracked in GH-8548): swizzling an
        // @available-gated UIViewController subclass realizes it, which crashes on OS versions below
        // its gate when it stores a gated newer-framework type. Excluding the class name skips it
        // before realization. This is the documented workaround until deferred (first-instantiation)
        // swizzling lands. The gated fixtures live in SubClassFinderRegressionViewController.swift;
        // removing these excludes re-arms the crash repro on the iOS 16.4 simulator.
        SentrySDKWrapper.additionalOptionsConfiguration = { options in
            options.swizzleClassNameExcludes.formUnion([
                "GatedIOS17ViewController",
                "GatedIOS26OnlyViewController"
            ])
        }

        SentrySDKWrapper.shared.startSentry()
        
        metricKit.receiveReports()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        metricKit.pauseReports()
        
        randomDistributionTimer?.invalidate()
        randomDistributionTimer = nil
    }
    
    // Workaround for 'Stored properties cannot be marked potentially unavailable with '@available''
    private var metricKit = MetricKitManager()
    
    /**
     * previously tried putting this in an AppDelegate.load override in ObjC, but it wouldn't run until
     * after a launch profiler would have an opportunity to run, since SentryProfiler.load would always run
     * first due to being dynamically linked in a framework module. it is sufficient to do it before
     * calling SentrySDK.startWithOptions to clear state for testProfiledAppLaunches because we don't make
     * any assertions on a launch profile the first launch of the app in that test
     */
    private func removeAppData() {
        print("[iOS-Swift] [debug] removing app data")
        let cache = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        [cache, appSupport].forEach {
            guard let files = FileManager.default.enumerator(atPath: $0) else { return }
            for item in files {
                try! FileManager.default.removeItem(atPath: ($0 as NSString).appendingPathComponent((item as! String)))
            }
        }

        SentrySDKOverrides.resetDefaults()
    }
}

extension Notification.Name {
    static let apnsTokenReceived = Notification.Name("io.sentry.apns-token-received")
}
