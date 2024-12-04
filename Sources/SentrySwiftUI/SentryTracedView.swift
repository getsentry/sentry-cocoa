#if canImport(SwiftUI)

import Foundation
import SwiftUI

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
import Sentry
#endif


/// A control to measure the performance of your views and send the result as a transaction to Sentry.io.
///
/// You create a transaction by wrapping your views with this.
/// Nested `SentryTracedView` will create child spans in the transaction.
///
///     SentryTracedView {
///         VStack {
///             // The part of your content you want to measure
///         }
///     }
///
/// By default, the transaction name will be the first root view, in the case above `VStack`.
/// You can give your transaction a custom name by providing the name parameter.
///
///     SentryTracedView("My Awesome Screen") {
///         VStack {
///             // The part of your content you want to measure
///         }
///     }
///
/// Alternatively you can use the view extension:
///
///     VStack {
///         //The part of your content you want to measure
///     }.sentryTrace("My Awesome Screen")
///
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public struct SentryTracedView<Content: View>: View {
    @State var viewAppeared = false
    
    let content: () -> Content
    let name: String
    let nameSource: SentryTransactionNameSource
    let waitforFullDisplay: Bool
    
    let traceOrigin = "auto.ui.swift_ui"
    
    /// Creates a view that measures the performance of its `content`.
    ///
    /// - Parameter viewName: The name that will be used for the span, if nil we try to get the name of the content class.
    /// - Parameter waitForFullDisplay: Indicates whether this view transaction should wait for `SentrySDK.reportFullyDisplayed()`
    /// in case you need to track some asyncronous task. This is ignored for any `SentryTracedView` that is child of another `SentryTracedView`
    /// - Parameter content: The content that you want to track the performance
    public init(_ viewName: String? = nil, waitForFullDisplay: Bool? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.name = viewName ?? SentryTracedView.extractName(content: Content.self)
        self.nameSource = viewName == nil ? .component : .custom
        self.waitforFullDisplay = waitForFullDisplay ?? SentrySDK.options?.enableTimeToFullDisplayTracing ?? false
    }
    
    private static func extractName(content: Any) -> String {
        var result = String(describing: content)
        
        if let index = result.firstIndex(of: "<") {
            result = String(result[result.startIndex ..< index])
        }
        
        return result
    }
    
    public var body: some View {
        var trace: SentryTracer?
        var spanId: SpanId?
        
        if !viewAppeared {
            trace = ensureTransactionExists()
            spanId = createAndPushBodySpan(transactionCreated: trace != nil)
        }
        
        defer {
            if let spanId = spanId {
                finishSpan(spanId)
            }
        }
        
        // We need to add a UIView to the view hierarchy to be able to
        // monitor ui life cycles. We will use the background modifier
        // to add this tracking view behind the content.
        return content()
            .background(TracingView(name: self.name, waitForFullDisplay: self.waitforFullDisplay, tracer: trace))
            .onAppear { viewAppeared = true }
    }
    
    private func ensureTransactionExists() -> SentryTracer? {
        guard SentryPerformanceTracker.shared.activeSpanId() == nil else { return nil }
        
        let transactionId = SentryPerformanceTracker.shared.startSpan(
            withName: name,
            nameSource: nameSource,
            operation: "ui.load",
            origin: traceOrigin
        )
        SentryPerformanceTracker.shared.pushActiveSpan(transactionId)
        
        //According to Apple's documentation, the call to body needs to be fast
        //and can be made many times in one frame. Therefore they don't use async code to process the view.
        //Scheduling to finish the transaction at the end of the main loop seems the least hack solution right now.
        //'onAppear' is not a suitable place to do this because it may happen before other view body property get called.
        DispatchQueue.main.async {
            self.finishSpan(transactionId)
        }
        
        return SentryPerformanceTracker.shared.getSpan(transactionId) as? SentryTracer
    }
    
    private func createAndPushBodySpan(transactionCreated: Bool) -> SpanId {
        let spanName = transactionCreated ? "\(name) - body" : name
        let spanId = SentryPerformanceTracker.shared.startSpan(
            withName: spanName,
            nameSource: nameSource,
            operation: "ui.load",
            origin: traceOrigin
        )
        SentryPerformanceTracker.shared.pushActiveSpan(spanId)
        return spanId
    }
    
    private func finishSpan(_ spanId: SpanId) {
        SentryPerformanceTracker.shared.popActiveSpan()
        SentryPerformanceTracker.shared.finishSpan(spanId)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    func sentryTrace(_ viewName: String? = nil) -> some View {
        return SentryTracedView(viewName) {
            return self
        }
    }
}
#endif
