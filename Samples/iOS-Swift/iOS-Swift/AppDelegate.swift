import SentrySampleShared
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var randomDistributionTimer: Timer?
    var window: UIWindow?
    
    var args: [String] {
        ProcessInfo.processInfo.arguments
    }
    
    var env: [String: String] {
        ProcessInfo.processInfo.environment
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("[iOS-Swift] [debug] launch arguments: \(args)")
        print("[iOS-Swift] [debug] launch environment: \(env)")

        if args.contains(SentrySDKOverrides.Special.wipeDataOnLaunch.rawValue) {
            removeAppData()
        }

        SentrySDKWrapper.shared.startSentry()
        SampleAppDebugMenu.shared.display()
        
        metricKit.receiveReports()

        return true
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
