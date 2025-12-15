import Sentry
import SwiftUI

struct ContentView: View {
    var addBreadcrumbAction: () -> Void = {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }
    
    var captureMessageAction: () -> Void = {
        func delayNonBlocking(timeout: Double = 0.2) {
            let group = DispatchGroup()
            group.enter()
            let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
            
            queue.asyncAfter(deadline: .now() + timeout) {
                group.leave()
            }
            
            group.wait()
        }
        
        delayNonBlocking(timeout: 5)
        
        SentrySDK.capture(message: "Yeah captured a message")
    }
    
    var captureErrorAction: () -> Void = {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error) { (scope) in
            scope.setTag(value: "value", key: "myTag")
        }
    }
    
    var captureNSExceptionAction: () -> Void = {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    var captureTransactionAction: () -> Void = {
        let dispatchQueue = DispatchQueue(label: "ContentView")
        
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "some operation", bindToScope: true)
        
        guard let imgUrl = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png") else {
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let dataTask = session.dataTask(with: imgUrl) { (_, _, _) in }
        dataTask.resume()
        
        dispatchQueue.async {
            if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                _ = FileManager.default.contents(atPath: path)
            }
        }
        
        dispatchQueue.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
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

    var oomCrashAction: () -> Void = {
        DispatchQueue.main.async {
            let megaByte = 1_024 * 1_024
            let memoryPageSize = NSPageSize()
            let memoryPages = megaByte / memoryPageSize

            while true {
                // Allocate one MB and set one element of each memory page to something.
                let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: megaByte)
                for i in 0..<memoryPages {
                    ptr[i * memoryPageSize] = 40
                }
            }
        }
    }

    var body: some View {
        VStack {
            Button(action: addBreadcrumbAction) {
                Text("Add Breadcrumb")
            }
            
            Button(action: captureMessageAction) {
                Text("Capture Message")
            }
            .accessibility(identifier: "captureMessageButton")
            
            Button(action: captureErrorAction) {
                Text("Capture Error")
            }
            
            Button(action: captureNSExceptionAction) {
                Text("Capture NSException")
            }
            
            Button(action: captureTransactionAction) {
                Text("Capture Transaction")
            }

            Button(action: {
                SentrySDK.crash()
            }) {
                Text("Crash")
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    self.asyncCrash1()
                }
            }) {
                Text("Async Crash")
            }

            Button(action: oomCrashAction) {
                Text("OOM Crash")
            }
            
            // MARK: - Metrics Examples
            
            Button(action: {
                // Counter metric with attributes using Attributable protocol - all types
                // Scalar types
                let interactionType = "button_press" // String constant
                let focused = true // Boolean constant
                let sessionId = 12_345 // Integer constant
                let interactionDuration = 0.5 // Double constant
                
                // Array types
                let interactionTypes = ["button_press", "swipe", "tap"] // String array constant
                let focusStates = [true, false, true] // Boolean array constant
                let sessionIds = [12_345, 12_346, 12_347] // Integer array constant
                let interactionDurations = [0.3, 0.5, 0.7] // Double array constant
                
                SentrySDK.metrics.count(
                    key: "tvos.app.interaction",
                    value: 1,
                    unit: "interaction",
                    attributes: [
                        // Scalar types - constants and literals
                        "interaction_type": interactionType, "device": "apple_tv", // String
                        "focused": focused, "active": false, // Boolean
                        "session_id": sessionId, "retry_count": 0, // Integer
                        "interaction_duration": interactionDuration, "avg_duration": 0.4, // Double
                        // Array types - constants and literals
                        "interaction_types": interactionTypes, "devices": ["apple_tv", "remote"], // String array
                        "focus_states": focusStates, "active_states": [true, false], // Boolean array
                        "session_ids": sessionIds, "retry_counts": [0, 1, 2], // Integer array
                        "interaction_durations": interactionDurations, "avg_durations": [0.3, 0.4] // Double array
                    ]
                )
            }) {
                Text("Record Counter Metric")
            }
            
            Button(action: {
                // Distribution metric with attributes using Attributable protocol - all types
                let frameTime = Double.random(in: 16...33)
                // Scalar types
                let scene = "main_menu" // String constant
                let vsyncEnabled = true // Boolean constant
                let frameCount = 60 // Integer constant
                let fps = 60.0 // Double constant
                
                // Array types
                let scenes = ["main_menu", "settings", "player"] // String array constant
                let vsyncStates = [true, false, true] // Boolean array constant
                let frameCounts = [30, 60, 120] // Integer array constant
                let fpsValues = [30.0, 60.0, 120.0] // Double array constant
                
                SentrySDK.metrics.distribution(
                    key: "tvos.rendering.frame_time",
                    value: frameTime,
                    unit: "millisecond",
                    attributes: [
                        // Scalar types - constants and literals
                        "scene": scene, "resolution": "4k", // String
                        "vsync_enabled": vsyncEnabled, "hdr_enabled": false, // Boolean
                        "frame_count": frameCount, "buffer_count": 3, // Integer
                        "fps": fps, "avg_fps": 59.5, // Double
                        // Array types - constants and literals
                        "scenes": scenes, "resolutions": ["4k", "1080p"], // String array
                        "vsync_states": vsyncStates, "hdr_states": [true, false], // Boolean array
                        "frame_counts": frameCounts, "buffer_counts": [2, 3, 4], // Integer array
                        "fps_values": fpsValues, "avg_fps_values": [59.0, 60.0] // Double array
                    ]
                )
            }) {
                Text("Record Distribution Metric")
            }
            
            Button(action: {
                // Gauge metric with attributes using Attributable protocol - all types
                let activeConnections = Double.random(in: 0...10)
                // Scalar types
                let networkType = "wifi" // String constant
                let secure = true // Boolean constant
                let port = 443 // Integer constant
                let maxBandwidth = 100.0 // Double constant
                
                // Array types
                let networkTypes = ["wifi", "ethernet", "cellular"] // String array constant
                let secureStates = [true, false, true] // Boolean array constant
                let ports = [80, 443, 8_080] // Integer array constant
                let maxBandwidths = [50.0, 100.0, 200.0] // Double array constant
                
                SentrySDK.metrics.gauge(
                    key: "tvos.network.connections",
                    value: activeConnections,
                    unit: "connection",
                    attributes: [
                        // Scalar types - constants and literals
                        "network_type": networkType, "protocol": "tcp", // String
                        "secure": secure, "compressed": false, // Boolean
                        "port": port, "max_connections": 100, // Integer
                        "max_bandwidth": maxBandwidth, "utilization": 0.75, // Double
                        // Array types - constants and literals
                        "network_types": networkTypes, "protocols": ["tcp", "udp"], // String array
                        "secure_states": secureStates, "compressed_states": [true, false], // Boolean array
                        "ports": ports, "max_connections_list": [50, 100, 200], // Integer array
                        "max_bandwidths": maxBandwidths, "utilizations": [0.7, 0.8] // Double array
                    ]
                )
            }) {
                Text("Record Gauge Metric")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
