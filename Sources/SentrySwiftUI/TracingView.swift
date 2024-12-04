#if canImport(SwiftUI)

import Foundation
import SwiftUI

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
#endif


@available(iOS 13, macOS 10.15, tvOS 13, *)
struct TracingView: UIViewRepresentable {
    
    let name: String
    let waitForFullDisplay: Bool
    let tracer: SentryTracer?
    
    class SentryTracingView: UIView {
        
        let tracer: SentryTracer?
        let tracker: SentryTimeToDisplayTracker?
        
        init(name: String, waitForFullDisplay: Bool, tracer: SentryTracer?) {
            self.tracer = tracer
            if let tracer = self.tracer {
                let tracker = SentryTimeToDisplayTracker(name: name, waitForFullDisplay: waitForFullDisplay)
                self.tracker = tracker
                SentryUIViewControllerPerformanceTracker.shared.setTimeToDisplay(tracker)
                tracker.start(for: tracer)
            } else {
                tracker = nil
            }
            
            super.init(frame: CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
      
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Reports initial display when this view is added to the view hierarchy
            // This is the equivalent of viewDidAppear of a UIViewController
            tracker?.reportInitialDisplay()
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = SentryTracingView(name: name, waitForFullDisplay: waitForFullDisplay, tracer: tracer)
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        //Intentionally left blank. Nothing to update here.
    }
}
#endif
