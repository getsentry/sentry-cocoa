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
                // Counter metric - demonstrates all supported attribute types as variables and literals
                // Showcases Attributable protocol and ExpressibleBy implementations
                let interactionType = "button_press"
                let focused = true
                let sessionId = 12_345
                let interactionDuration = 0.5
                
                let interactionTypes = ["button_press", "swipe", "tap"]
                let focusStates = [true, false, true]
                let sessionIds = [12_345, 12_346, 12_347]
                let interactionDurations = [0.3, 0.5, 0.7]
                
                SentrySDK.metrics.count(
                    key: "tvos.app.interaction",
                    value: 1,
                    unit: "interaction",
                    attributes: [
                        // -- Variables --
                        "interaction_type": interactionType, // String
                        "focused": focused, // Boolean
                        "session_id": sessionId, // Integer
                        "interaction_duration": interactionDuration, // Double

                        "interaction_types": interactionTypes, // String array
                        "focus_states": focusStates, // Boolean array
                        "session_ids": sessionIds, // Integer array
                        "interaction_durations": interactionDurations, // Double array
                        
                        // -- Literals (showcases ExpressibleBy implementations) --
                        "device": "apple_tv", // String
                        "active": false, // Boolean
                        "retry_count": 0, // Integer
                        "avg_duration": 0.4, // Double

                        "devices": ["apple_tv", "remote"], // String array
                        "active_states": [true, false], // Boolean array
                        "retry_counts": [0, 1, 2], // Integer array
                        "avg_durations": [0.3, 0.4] // Double array
                    ]
                )
            }) {
                Text("Record Counter Metric")
            }
            
            Button(action: {
                // Distribution metric - demonstrates all supported attribute types as variables and literals
                // Showcases Attributable protocol and ExpressibleBy implementations
                let frameTime = Double.random(in: 16...33)
                let scene = "main_menu"
                let vsyncEnabled = true
                let frameCount = 60
                let fps = 60.0
                
                let scenes = ["main_menu", "settings", "player"]
                let vsyncStates = [true, false, true]
                let frameCounts = [30, 60, 120]
                let fpsValues = [30.0, 60.0, 120.0]
                
                SentrySDK.metrics.distribution(
                    key: "tvos.rendering.frame_time",
                    value: frameTime,
                    unit: "millisecond",
                    attributes: [
                        // -- Variables --
                        "scene": scene, // String
                        "vsync_enabled": vsyncEnabled, // Boolean
                        "frame_count": frameCount, // Integer
                        "fps": fps, // Double

                        "scenes": scenes, // String array
                        "vsync_states": vsyncStates, // Boolean array
                        "frame_counts": frameCounts, // Integer array
                        "fps_values": fpsValues, // Double array
                        
                        // -- Literals (showcases ExpressibleBy implementations) --
                        "resolution": "4k", // String
                        "hdr_enabled": false, // Boolean
                        "buffer_count": 3, // Integer
                        "avg_fps": 59.5, // Double

                        "resolutions": ["4k", "1080p"], // String array
                        "hdr_states": [true, false], // Boolean array
                        "buffer_counts": [2, 3, 4], // Integer array
                        "avg_fps_values": [59.0, 60.0] // Double array
                    ]
                )
            }) {
                Text("Record Distribution Metric")
            }
            
            Button(action: {
                // Gauge metric - demonstrates all supported attribute types as variables and literals
                // Showcases Attributable protocol and ExpressibleBy implementations
                let activeConnections = Double.random(in: 0...10)
                let networkType = "wifi"
                let secure = true
                let port = 443
                let maxBandwidth = 100.0
                
                let networkTypes = ["wifi", "ethernet", "cellular"]
                let secureStates = [true, false, true]
                let ports = [80, 443, 8_080]
                let maxBandwidths = [50.0, 100.0, 200.0]
                
                SentrySDK.metrics.gauge(
                    key: "tvos.network.connections",
                    value: activeConnections,
                    unit: "connection",
                    attributes: [
                        // -- Variables --
                        "network_type": networkType, // String
                        "secure": secure, // Boolean
                        "port": port, // Integer
                        "max_bandwidth": maxBandwidth, // Double

                        "network_types": networkTypes, // String array
                        "secure_states": secureStates, // Boolean array
                        "ports": ports, // Integer array
                        "max_bandwidths": maxBandwidths, // Double array
                        
                        // -- Literals (showcases ExpressibleBy implementations) --
                        "protocol": "tcp", // String
                        "compressed": false, // Boolean
                        "max_connections": 100, // Integer
                        "utilization": 0.75, // Double

                        "protocols": ["tcp", "udp"], // String array
                        "compressed_states": [true, false], // Boolean array
                        "max_connections_list": [50, 100, 200], // Integer array
                        "utilizations": [0.7, 0.8] // Double array
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
