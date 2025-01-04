import Sentry
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var randomDistributionTimer: Timer?
    var window: UIWindow?
    
    var args: [String] {
        let args = ProcessInfo.processInfo.arguments
        print("[iOS-Swift] [debug] launch arguments: \(args)")
        return args
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if args.contains("--io.sentry.wipe-data") {
            removeAppData()
        }
        if !args.contains("--skip-sentry-init") {
            SentrySDKWrapper.shared.startSentry()
        }
        
        if #available(iOS 15.0, *) {
            metricKit.receiveReports()
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if #available(iOS 15.0, *) {
            metricKit.pauseReports()
        }
        
        randomDistributionTimer?.invalidate()
        randomDistributionTimer = nil
    }
    
    // Workaround for 'Stored properties cannot be marked potentially unavailable with '@available''
    private var _metricKit: Any?
    @available(iOS 15.0, *)
    fileprivate var metricKit: MetricKitManager {
        if _metricKit == nil {
            _metricKit = MetricKitManager()
        }
        
        // We know the type so it's fine to force cast.
        // swiftlint:disable force_cast
        return _metricKit as! MetricKitManager
        // swiftlint:enable force_cast
    }
    
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
    }
}
