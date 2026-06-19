import Sentry
import SentrySampleShared
import UIKit

// swiftlint:disable force_cast force_try force_unwrapping
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
        SentrySDKWrapper.shared.startSentry()
        SampleAppDebugMenu.shared.display()
        
        metricKit.receiveReports()

        captureExampleFlamegraph()

        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        metricKit.pauseReports()
        
        randomDistributionTimer?.invalidate()
        randomDistributionTimer = nil
    }
    
    // Workaround for 'Stored properties cannot be marked potentially unavailable with '@available''
    private var metricKit = MetricKitManager()
    
    // swiftlint:disable function_body_length
    private func captureExampleFlamegraph() {
        // Build a fake flamegraph tree flattened into frames with parent_index + sample_count.
        //
        //   main (samples: 10)
        //   ├── UIApplicationMain (samples: 10)
        //   │   ├── -[AppDelegate application:didFinishLaunching:] (samples: 10)
        //   │   │   ├── loadConfiguration (samples: 4)
        //   │   │   │   ├── parseJSON (samples: 3)
        //   │   │   │   └── validateConfig (samples: 1)
        //   │   │   ├── setupDatabase (samples: 3)
        //   │   │   │   └── runMigrations (samples: 2)
        //   │   │   └── buildUI (samples: 3)
        //   │   │       ├── loadStoryboard (samples: 1)
        //   │   │       └── layoutSubviews (samples: 2)

        struct FrameData {
            let function: String
            let package: String
            let parentIndex: Int
            let sampleCount: Int
        }
        let frameData: [FrameData] = [
            // 0
            FrameData(function: "main", package: "iOS-Swift", parentIndex: -1, sampleCount: 10),
            // 1
            FrameData(function: "UIApplicationMain", package: "UIKitCore", parentIndex: 0, sampleCount: 10),
            // 2
            FrameData(function: "-[AppDelegate application:didFinishLaunchingWithOptions:]", package: "iOS-Swift", parentIndex: 1, sampleCount: 10),
            // 3
            FrameData(function: "loadConfiguration", package: "iOS-Swift", parentIndex: 2, sampleCount: 4),
            // 4
            FrameData(function: "parseJSON", package: "iOS-Swift", parentIndex: 3, sampleCount: 3),
            // 5
            FrameData(function: "validateConfig", package: "iOS-Swift", parentIndex: 3, sampleCount: 1),
            // 6
            FrameData(function: "setupDatabase", package: "iOS-Swift", parentIndex: 2, sampleCount: 3),
            // 7
            FrameData(function: "runMigrations", package: "iOS-Swift", parentIndex: 6, sampleCount: 2),
            // 8
            FrameData(function: "buildUI", package: "iOS-Swift", parentIndex: 2, sampleCount: 3),
            // 9
            FrameData(function: "loadStoryboard", package: "UIKitCore", parentIndex: 8, sampleCount: 1),
            // 10
            FrameData(function: "layoutSubviews", package: "UIKitCore", parentIndex: 8, sampleCount: 2)
        ]

        let frames: [Frame] = frameData.enumerated().map { index, data in
            let frame = Frame()
            frame.function = data.function
            frame.package = data.package
            frame.parentIndex = NSNumber(value: data.parentIndex)
            frame.sampleCount = NSNumber(value: data.sampleCount)
            frame.inApp = NSNumber(value: data.package == "iOS-Swift")
            frame.instructionAddress = String(format: "0x%016x", 0x1000_0000 + index * 0x100)
            frame.imageAddress = "0x0000000010000000"
            return frame
        }

        let stacktrace = SentryStacktrace(frames: frames, registers: [:])
        stacktrace.snapshot = NSNumber(value: true)

        let thread = SentryThread(threadId: NSNumber(value: 0))
        thread.name = "main"
        thread.crashed = NSNumber(value: false)
        thread.current = NSNumber(value: true)
        thread.isMain = NSNumber(value: true)
        thread.stacktrace = stacktrace

        let mechanism = Mechanism(type: "mx_hang_diagnostic")
        mechanism.handled = NSNumber(value: true)
        mechanism.synthetic = NSNumber(value: true)

        let exception = Exception(
            value: "Example flamegraph hang: 6.6 sec",
            type: "MXHangDiagnostic"
        )
        exception.mechanism = mechanism
        exception.stacktrace = stacktrace
        exception.threadId = NSNumber(value: 0)

        let event = Event(level: .warning)
        event.threads = [thread]
        event.exceptions = [exception]
        event.tags = ["example": "flamegraph"]

        SentrySDK.capture(event: event)
        print("[iOS-Swift] [debug] captured example flamegraph event")
    }
    // swiftlint:enable function_body_length

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
