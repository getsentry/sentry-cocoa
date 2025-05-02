#if canImport(SwiftUI)

import Foundation
import Sentry
import SwiftUI

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
#endif

class SentryTraceViewModel {
    private var transactionId: SpanId?
    private var viewAppeared: Bool = false
    private var tracker: SentryTimeToDisplayTracker?
    
    let name: String
    let nameSource: SentryTransactionNameSource
    let waitForFullDisplay: Bool
    let traceOrigin = SentryTraceOrigin.autoUISwiftUI
    
    init(name: String, nameSource: SentryTransactionNameSource, waitForFullDisplay: Bool?) {
        self.name = name
        self.nameSource = nameSource
        self.waitForFullDisplay = waitForFullDisplay ?? SentrySDK.options?.enableTimeToFullDisplayTracing ?? false
    }
    
    func startSpan() -> SpanId? {
        guard !viewAppeared else { return nil }
        
        let trace = startRootTransaction()
        let name = trace != nil ? "\(name) - body" : name
        return createBodySpan(name: name)
    }
    
    private func startRootTransaction() -> SentryTracer? {
        let performanceTracker = SentryDependencyContainer.sharedInstance().performanceTracker
        guard performanceTracker.activeSpanId() == nil else { return nil }

        let transactionId = performanceTracker.startSpan(
            withName: name,
            nameSource: nameSource,
            operation: "ui.load",
            origin: traceOrigin
        )
        performanceTracker.pushActiveSpan(transactionId)
        self.transactionId = transactionId

        let tracer = performanceTracker.getSpan(transactionId) as? SentryTracer
#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
        if let tracer = tracer {
            tracker = SentryUIViewControllerPerformanceTracker.shared.startTimeToDisplay(forScreen: name, waitForFullDisplay: waitForFullDisplay, tracer: tracer)
        }
#endif
        return tracer
    }
    
    private func createBodySpan(name: String) -> SpanId {
        let performanceTracker = SentryDependencyContainer.sharedInstance().performanceTracker
        let spanId = performanceTracker.startSpan(
            withName: name,
            nameSource: nameSource,
            operation: "ui.load",
            origin: traceOrigin
        )
        performanceTracker.pushActiveSpan(spanId)
        return spanId
    }
    
    func finishSpan(_ spanId: SpanId) {
        let performanceTracker = SentryDependencyContainer.sharedInstance().performanceTracker
        performanceTracker.popActiveSpan()
        performanceTracker.finishSpan(spanId)
    }
    
    func viewDidAppear() {
        guard !viewAppeared else { return }
        viewAppeared = true
        tracker?.reportInitialDisplay()
        
        if let transactionId = transactionId {
            // According to Apple's documentation, the call to `body` needs to be fast
            // and can be made many times in one frame. Therefore they don't use async code to process the view.
            // Scheduling to finish the transaction at the end of the main loop seems the least hack solution right now.
            // Calling it directly from 'onAppear' is not a suitable place to do this
            // because it may happen before other view `body` property get called.
            DispatchQueue.main.async {
                self.finishSpan(transactionId)
            }
        }
    }
}

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
    @State private var viewModel: SentryTraceViewModel
    let content: () -> Content
    
#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
    /// Creates a view that measures the performance of its `content`.
    ///
    /// - Parameter viewName: The name that will be used for the span, if nil we try to get the name of the content class.
    /// - Parameter waitForFullDisplay: Indicates whether this view transaction should wait for `SentrySDK.reportFullyDisplayed()`
    /// in case you need to track some asyncronous task. This is ignored for any `SentryTracedView` that is child of another `SentryTracedView`.
    /// If nil, it will use the `enableTimeToFullDisplayTracing` option from the SDK.
    /// - Parameter content: The content that you want to track the performance
    public init(_ viewName: String? = nil, waitForFullDisplay: Bool? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        let name = viewName ?? SentryTracedView.extractName(content: Content.self)
        let nameSource = viewName == nil ? SentryTransactionNameSource.component : SentryTransactionNameSource.custom
        let initialViewModel = SentryTraceViewModel(name: name, nameSource: nameSource, waitForFullDisplay: waitForFullDisplay)
        _viewModel = State(initialValue: initialViewModel)
    }
#else
    /// Creates a view that measures the performance of its `content`.
    ///
    /// - Parameter viewName: The name that will be used for the span, if nil we try to get the name of the content class.
    /// - Parameter content: The content that you want to track the performance
    public init(_ viewName: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        let name = viewName ?? SentryTracedView.extractName(content: Content.self)
        let nameSource = viewName == nil ? SentryTransactionNameSource.component : SentryTransactionNameSource.custom
        let initialViewModel = SentryTraceViewModel(name: name, nameSource: nameSource, waitForFullDisplay: false)
        _viewModel = State(initialValue: initialViewModel)
    }
#endif
    
    private static func extractName(content: Any) -> String {
        var result = String(describing: content)
        
        if let index = result.firstIndex(of: "<") {
            result = String(result[result.startIndex ..< index])
        }
        
        return result
    }
    
    public var body: some View {
        let spanId = viewModel.startSpan()
        
        defer {
            if let spanId = spanId {
                viewModel.finishSpan(spanId)
            }
        }
        
        return content().onAppear(perform: viewModel.viewDidAppear)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {

#if canImport(UIKit) && os(iOS) || os(tvOS)
    func sentryTrace(_ viewName: String? = nil, waitForFullDisplay: Bool? = nil) -> some View {
        return SentryTracedView(viewName, waitForFullDisplay: waitForFullDisplay) {
            return self
        }
    }
#else
    func sentryTrace(_ viewName: String? = nil) -> some View {
        return SentryTracedView(viewName) {
            return self
        }
    }
#endif

}
#endif
