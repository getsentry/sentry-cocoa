import Cocoa
import Sentry
import SentrySampleShared
import SwiftUI

class ViewController: NSViewController {

    private let diskWriteException = DiskWriteException()

    @IBOutlet weak var uiTestDataMarshalingField: NSTextField!

    @IBAction func addBreadCrumb(_ sender: Any) {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }

    @IBAction func captureMessage(_ sender: Any) {
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }

    @IBAction func captureError(_ sendder: Any) {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error) { (scope) in
            scope.setTag(value: "value", key: "myTag")
        }
    }

    @IBAction func captureException(_ sender: Any) {
        let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        SentrySDK.capture(exception: exception, scope: scope)
    }

    @IBAction func raiseNSException(_ sender: Any) {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSException raise"), reason: "Raised NSException", userInfo: userInfo)
        exception.raise()
    }

    @IBAction func reportNSException(_ sender: Any) {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSApplication report"), reason: "It doesn't work", userInfo: userInfo)
        NSApplication.shared.reportException(exception)
    }

    @IBAction func throwNSRangeException(_ sender: Any) {
        CppWrapper().throwNSRangeException()
    }

    @IBAction func throwNSExceptionInNSView(_ sender: Any) {
        let customView = RaiseNSExceptionInLayoutNSView()
        customView.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        view.addSubview(customView)
    }
    
    @IBAction func captureTransaction(_ sender: Any) {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "some operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
    }

    @IBAction func sentryCrash(_ sender: Any) {
        SentrySDK.crash()
    }

    @IBAction func cppException(_ sender: Any) {
        let wrapper = CppWrapper()
        wrapper.throwCPPException()
    }

    @IBAction func rethrowNoActiveCppException(_ sender: Any) {
        let wrapper = CppWrapper()
        wrapper.rethrowNoActiveCPPException()
    }

    @IBAction func cppExceptionFromBGThread(_ sender: Any) {
        DispatchQueue.global().async {
           let wrapper = CppWrapper()
           wrapper.throwCPPException()
        }
    }

    @IBAction func noExceptCppException(_ sender: Any) {
        let wrapper = CppWrapper()
        wrapper.noExceptCppException()
    }
    
    @IBAction func asyncCrash(_ sender: Any) {
        DispatchQueue.main.async {
            self.asyncCrash1()
        }
    }

    @IBAction func diskWriteException(_ sender: Any) {
        diskWriteException.continuouslyWriteToDisk()
        // As we are writing to disk continuously we would keep adding spans to this UIEventTransaction.
        SentrySDK.span?.finish()
    }

    @available(macOS 10.15, *)
    @IBAction func showSwiftUIView(_ sender: Any) {
        let controller = NSHostingController(rootView: SwiftUIView())
        let window = NSWindow(contentViewController: controller)
        window.setContentSize(NSSize(width: 300, height: 200))
        let windowController = NSWindowController(window: window)
        windowController.showWindow(self)
    }

    @IBAction func startProfile(_ sender: Any) {
        SentrySDK.startProfiler()
    }
    @IBAction func stopProfile(_ sender: Any) {
        SentrySDK.stopProfiler()
    }

    @IBAction func retrieveProfileChunk(_ sender: Any) {
        uiTestDataMarshalingField.stringValue = "<fetching...>"
        withProfile(continuous: true) { file in
            handleContents(file: file)
        }
    }

    var sentryBasePath: String {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        let sandboxedCachesDirectory: String
        if cachesDirectory.contains(bundleIdentifier) {
            sandboxedCachesDirectory = cachesDirectory
        } else {
            sandboxedCachesDirectory = (cachesDirectory as NSString).appendingPathComponent(bundleIdentifier)
        }
        return (sandboxedCachesDirectory as NSString).appendingPathComponent("io.sentry")
    }

    func withProfile(continuous: Bool, block: (URL?) -> Void) {
        let fm = FileManager.default
        let dir = (sentryBasePath as NSString).appendingPathComponent(continuous ? "continuous-profiles" : "trace-profiles")
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: dir, isDirectory: &isDirectory), isDirectory.boolValue else {
            block(nil)
            return
        }

        let count = try! fm.contentsOfDirectory(atPath: dir).count
        //swiftlint:disable empty_count
        guard continuous || count > 0 else {
            //swiftlint:enable empty_count
            uiTestDataMarshalingField.stringValue = "<missing>"
            return
        }
        let fileName = "profile\(continuous ? 0 : count - 1)"
        let fullPath = "\(dir)/\(fileName)"

        if fm.fileExists(atPath: fullPath) {
            let url = NSURL.fileURL(withPath: fullPath)
            block(url)
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                SentrySDK.capture(error: error)
            }
            return
        }

        block(nil)
    }

    func handleContents(file: URL?) {
        guard let file = file else {
            uiTestDataMarshalingField.stringValue = "<missing>"
            return
        }

        do {
            let data = try Data(contentsOf: file)
            let contents = data.base64EncodedString()
            print("[iOS-Swift] [debug] [ProfilingViewController] contents of file at \(file): \(String(describing: String(data: data, encoding: .utf8)))")
            uiTestDataMarshalingField.stringValue = contents
        } catch {
            SentrySDK.capture(error: error)
            uiTestDataMarshalingField.stringValue = "<empty>"
        }
    }

    @IBAction func checkProfileMarkerFileExistence(_ sender: Any) {
        let launchProfileMarkerPath = (sentryBasePath as NSString).appendingPathComponent("profileLaunch")
        if FileManager.default.fileExists(atPath: launchProfileMarkerPath) {
            uiTestDataMarshalingField.stringValue = "<exists>"
        } else {
            uiTestDataMarshalingField.stringValue = "<missing>"
        }
    }
    
    // MARK: - Metrics Examples
    
    @IBAction func recordSampleMetrics(_ sender: Any) {
        // Counter metric with attributes using Attributable protocol - all types
        // Scalar types
        let actionType = "button_click" // String constant
        let windowActive = true // Boolean constant
        let clickCount = 42 // Integer constant
        let clickDuration = 0.123 // Double constant
        
        // Array types
        let actionTypes = ["button_click", "key_press", "menu_select"] // String array constant
        let windowStates = [true, false, true] // Boolean array constant
        let clickCounts = [10, 20, 30] // Integer array constant
        let clickDurations = [0.1, 0.2, 0.3] // Double array constant
        
        SentrySDK.metrics.count(
            key: "macos.app.action",
            value: 1,
            unit: "action",
            attributes: [
                // Scalar types - constants and literals
                "action_type": actionType, "window": "main", // String
                "window_active": windowActive, "focused": false, // Boolean
                "click_count": clickCount, "retry_count": 3, // Integer
                "click_duration": clickDuration, "avg_duration": 0.15, // Double
                // Array types - constants and literals
                "action_types": actionTypes, "windows": ["main", "secondary"], // String array
                "window_states": windowStates, "focus_states": [true, false], // Boolean array
                "click_counts": clickCounts, "retry_counts": [1, 2, 3], // Integer array
                "click_durations": clickDurations, "avg_durations": [0.1, 0.2] // Double array
            ]
        )
        
        // Distribution metric with attributes using Attributable protocol - all types
        let responseTime = Double.random(in: 10...100)
        // Scalar types
        let endpoint = "/api/data" // String constant
        let cached = false // Boolean constant
        let statusCode = 200 // Integer constant
        let responseSize = 1_024.5 // Double constant
        
        // Array types
        let endpoints = ["/api/data", "/api/users", "/api/orders"] // String array constant
        let cacheStates = [true, false, true] // Boolean array constant
        let statusCodes = [200, 201, 404] // Integer array constant
        let responseSizes = [512.0, 1_024.0, 2_048.0] // Double array constant
        
        SentrySDK.metrics.distribution(
            key: "macos.network.response_time",
            value: responseTime,
            unit: "millisecond",
            attributes: [
                // Scalar types - constants and literals
                "endpoint": endpoint, "protocol": "https", // String
                "cached": cached, "compressed": true, // Boolean
                "status_code": statusCode, "retry_count": 0, // Integer
                "response_size": responseSize, "compression_ratio": 0.75, // Double
                // Array types - constants and literals
                "endpoints": endpoints, "protocols": ["https", "http"], // String array
                "cache_states": cacheStates, "compressed_states": [true, false], // Boolean array
                "status_codes": statusCodes, "retry_counts": [0, 1, 2], // Integer array
                "response_sizes": responseSizes, "compression_ratios": [0.7, 0.8] // Double array
            ]
        )
        
        // Gauge metric with attributes using Attributable protocol - all types
        let memoryUsage = Double.random(in: 512...2_048)
        // Scalar types
        let process = "main_app" // String constant
        let compressed = true // Boolean constant
        let pressureLevel = 2 // Integer constant
        let compressionRatio = 0.85 // Double constant
        
        // Array types
        let processes = ["main_app", "helper", "daemon"] // String array constant
        let compressedStates = [true, false, true] // Boolean array constant
        let pressureLevels = [1, 2, 3] // Integer array constant
        let compressionRatios = [0.8, 0.9, 0.7] // Double array constant
        
        SentrySDK.metrics.gauge(
            key: "macos.memory.usage",
            value: memoryUsage,
            unit: "megabyte",
            attributes: [
                // Scalar types - constants and literals
                "process": process, "memory_type": "resident", // String
                "compressed": compressed, "swapped": false, // Boolean
                "pressure_level": pressureLevel, "thread_count": 42, // Integer
                "compression_ratio": compressionRatio, "utilization": 0.75, // Double
                // Array types - constants and literals
                "processes": processes, "memory_types": ["resident", "virtual"], // String array
                "compressed_states": compressedStates, "swapped_states": [false, true], // Boolean array
                "pressure_levels": pressureLevels, "thread_counts": [10, 20, 30], // Integer array
                "compression_ratios": compressionRatios, "utilizations": [0.7, 0.8] // Double array
            ]
        )
    }

    func asyncCrash1() {
        DispatchQueue.main.async {
            self.asyncCrash2()
        }
    }

    func asyncCrash2() {
        DispatchQueue.main.async {
            SentrySDK.crash()
        }
    }
}
