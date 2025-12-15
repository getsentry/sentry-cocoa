import RealityKit
import Sentry
import SentrySwiftUI
import SwiftUI

struct ContentView: View {

    var addBreadcrumbAction: () -> Void = {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }

    var captureMessageAction: () -> Void = {
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
        SentryTracedView("Content View Body") {
            NavigationStack {
                HStack {
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
                    }
                    VStack {
                        
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
                        
                        Button(action: {
                            Thread.sleep(forTimeInterval: 3.0)
                        }) {
                            Text("Cause ANR")
                        }
                        
                        NavigationLink(destination: LoremIpsumView()) {
                            Text("Show Detail View 1")
                        }
                    }
                    
                    // MARK: - Metrics Examples
                    
                    VStack {
                        Button(action: {
                            // Counter metric with attributes using Attributable protocol - all types
                            // Scalar types
                            let interactionType = "gesture" // String constant
                            let handTracking = true // Boolean constant
                            let sessionId = 98_765 // Integer constant
                            let interactionAccuracy = 0.95 // Double constant
                            
                            // Array types
                            let interactionTypes = ["gesture", "pinch", "grab"] // String array constant
                            let handTrackingStates = [true, false, true] // Boolean array constant
                            let sessionIds = [98_765, 98_766, 98_767] // Integer array constant
                            let interactionAccuracies = [0.9, 0.95, 0.98] // Double array constant
                            
                            SentrySDK.metrics.count(
                                key: "visionos.app.interaction",
                                value: 1,
                                unit: "interaction",
                                attributes: [
                                    // Scalar types - constants and literals
                                    "interaction_type": interactionType, "device": "vision_pro", // String
                                    "hand_tracking": handTracking, "eye_tracking": false, // Boolean
                                    "session_id": sessionId, "retry_count": 0, // Integer
                                    "interaction_accuracy": interactionAccuracy, "avg_accuracy": 0.93, // Double
                                    // Array types - constants and literals
                                    "interaction_types": interactionTypes, "devices": ["vision_pro", "hand"], // String array
                                    "hand_tracking_states": handTrackingStates, "eye_tracking_states": [true, false], // Boolean array
                                    "session_ids": sessionIds, "retry_counts": [0, 1, 2], // Integer array
                                    "interaction_accuracies": interactionAccuracies, "avg_accuracies": [0.9, 0.95] // Double array
                                ]
                            )
                        }) {
                            Text("Record Counter Metric")
                        }
                        
                        Button(action: {
                            // Distribution metric with attributes using Attributable protocol - all types
                            let renderTime = Double.random(in: 8...16)
                            // Scalar types
                            let scene = "immersive_space" // String constant
                            let foveated = true // Boolean constant
                            let frameCount = 90 // Integer constant
                            let fps = 90.0 // Double constant
                            
                            // Array types
                            let scenes = ["immersive_space", "shared_space", "full_space"] // String array constant
                            let foveatedStates = [true, false, true] // Boolean array constant
                            let frameCounts = [60, 90, 120] // Integer array constant
                            let fpsValues = [60.0, 90.0, 120.0] // Double array constant
                            
                            SentrySDK.metrics.distribution(
                                key: "visionos.rendering.frame_time",
                                value: renderTime,
                                unit: "millisecond",
                                attributes: [
                                    // Scalar types - constants and literals
                                    "scene": scene, "render_mode": "passthrough", // String
                                    "foveated": foveated, "hdr_enabled": true, // Boolean
                                    "frame_count": frameCount, "buffer_count": 2, // Integer
                                    "fps": fps, "avg_fps": 89.5, // Double
                                    // Array types - constants and literals
                                    "scenes": scenes, "render_modes": ["passthrough", "occlusion"], // String array
                                    "foveated_states": foveatedStates, "hdr_states": [true, false], // Boolean array
                                    "frame_counts": frameCounts, "buffer_counts": [1, 2, 3], // Integer array
                                    "fps_values": fpsValues, "avg_fps_values": [89.0, 90.0] // Double array
                                ]
                            )
                        }) {
                            Text("Record Distribution Metric")
                        }
                        
                        Button(action: {
                            // Gauge metric with attributes using Attributable protocol - all types
                            let spatialAnchors = Double.random(in: 0...50)
                            // Scalar types
                            let spaceType = "full_space" // String constant
                            let tracked = true // Boolean constant
                            let maxAnchors = 100 // Integer constant
                            let trackingAccuracy = 0.98 // Double constant
                            
                            // Array types
                            let spaceTypes = ["full_space", "shared_space", "windowed"] // String array constant
                            let trackedStates = [true, false, true] // Boolean array constant
                            let maxAnchorsList = [50, 100, 200] // Integer array constant
                            let trackingAccuracies = [0.95, 0.98, 0.99] // Double array constant
                            
                            SentrySDK.metrics.gauge(
                                key: "visionos.spatial.anchors",
                                value: spatialAnchors,
                                unit: "anchor",
                                attributes: [
                                    // Scalar types - constants and literals
                                    "space_type": spaceType, "anchor_type": "plane", // String
                                    "tracked": tracked, "stabilized": false, // Boolean
                                    "max_anchors": maxAnchors, "update_count": 42, // Integer
                                    "tracking_accuracy": trackingAccuracy, "stability": 0.97, // Double
                                    // Array types - constants and literals
                                    "space_types": spaceTypes, "anchor_types": ["plane", "mesh"], // String array
                                    "tracked_states": trackedStates, "stabilized_states": [true, false], // Boolean array
                                    "max_anchors_list": maxAnchorsList, "update_counts": [10, 20, 30], // Integer array
                                    "tracking_accuracies": trackingAccuracies, "stabilities": [0.95, 0.98] // Double array
                                ]
                            )
                        }) {
                            Text("Record Gauge Metric")
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
