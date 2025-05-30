import SentrySampleShared
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
            var previousEncodedViewData: Data?
            var counter = 0
            SentrySDKWrapper.shared.startSentry { options in
                options.sessionReplay.frameRate = 10
                if FileManager.default.fileExists(atPath: "/tmp/workdir") {
                    try! FileManager.default.removeItem(atPath: "/tmp/workdir")
                }
                try! FileManager.default.createDirectory(atPath: "/tmp/workdir", withIntermediateDirectories: true, attributes: nil)
                options.sessionReplay.onNewFrame = { _, viewHiearchy, redactRegions, renderedViewImage, maskedViewImage  in
                    guard TransactionsViewController.isTransitioning else { return }
                    do {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                        let encodedViewData = try encoder.encode(viewHiearchy)
                        if let previousEncodedViewData = previousEncodedViewData {
                            if encodedViewData == previousEncodedViewData {
                                return
                            }
                        }
                        previousEncodedViewData = encodedViewData
//                        if counter >= 2 {
//                            return
//                        }
                        counter += 1

                        let viewHiearchyPath = "/tmp/workdir/\(counter)-0_view.json"
                        let regionsPath = "/tmp/workdir/\(counter)-1_regions.json"
                        let imagePath = "/tmp/workdir/\(counter)-2_image.png"
                        let maskedImagePath = "/tmp/workdir/\(counter)-3_masked.png"

                        try encodedViewData.write(to: URL(fileURLWithPath: viewHiearchyPath))

                        let encodedRegionsData = try encoder.encode(redactRegions)
                        try encodedRegionsData.write(to: URL(fileURLWithPath: regionsPath))

                        let encodedImage = renderedViewImage.pngData()
                        try encodedImage?.write(to: URL(fileURLWithPath: imagePath))

                        let encodedMaskedImage = maskedViewImage.pngData()
                        try encodedMaskedImage?.write(to: URL(fileURLWithPath: maskedImagePath))

                    } catch {
                        print("Could not encode redact regions. Error: \(error)")
                    }
                }
            }
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

        SentrySDKOverrides.resetDefaults()
    }
}
