#if canImport(SwiftUI) && (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

import Foundation
import SwiftUI

@_implementationOnly import _SentryPrivate

class SentryTraceViewModel {
    private var transactionId: SpanId?
    private var viewAppeared: Bool = false
    private var swiftUISpanHelper: SentryObjCSwiftUISpanHelper?
    
    let name: String
    let nameSource: SentryTransactionNameSource
    let waitForFullDisplay: Bool
    let traceOrigin = SentryTraceOriginAutoUISwiftUI
    
    init(name: String, nameSource: SentryTransactionNameSource, waitForFullDisplay: Bool?) {
        self.name = name
        self.nameSource = nameSource
        self.waitForFullDisplay = waitForFullDisplay ?? SentrySDKInternal.options?.enableTimeToFullDisplayTracing ?? false
    }
    
    func startSpan() -> SpanId? {
        guard !viewAppeared else { return nil }
        
        let hasTrace = startRootTransaction()
        let name = hasTrace ? "\(name) - body" : name
        return createBodySpan(name: name)
    }
    
    private func startRootTransaction() -> Bool {
        guard SentryPerformanceTracker.shared.activeSpanId() == nil else { return false }
        
        let transactionId = SentryPerformanceTracker.shared.startSpan(
            withName: name,
            nameSource: nameSource.rawValue,
            operation: SentrySpanOperationUiLoad,
            origin: traceOrigin
        )
        SentryPerformanceTracker.shared.pushActiveSpan(transactionId)
        self.transactionId = transactionId
        let swiftUITraceHelper = SentryDefaultUIViewControllerPerformanceTracker.startTimeToDisplay(forScreen: name, waitForFullDisplay: waitForFullDisplay, transactionId: transactionId)
        self.swiftUISpanHelper = swiftUITraceHelper
        return swiftUITraceHelper.hasSpan
    }
    
    private func createBodySpan(name: String) -> SpanId {
        let spanId = SentryPerformanceTracker.shared.startSpan(
            withName: name,
            nameSource: nameSource.rawValue,
            operation: SentrySpanOperationUiLoad,
            origin: traceOrigin
        )
        SentryPerformanceTracker.shared.pushActiveSpan(spanId)
        return spanId
    }
    
    func finishSpan(_ spanId: SpanId) {
        SentryPerformanceTracker.shared.popActiveSpan()
        SentryPerformanceTracker.shared.finishSpan(spanId)
    }
    
    func viewDidAppear() {
        guard !viewAppeared else { return }
        viewAppeared = true
        swiftUISpanHelper?.reportInitialDisplay()
        
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
@available(iOS 15.0, tvOS 15.0, *)
public struct SentryTracedView<Content: View>: View {
    @State private var viewModel: SentryTraceViewModel
    let content: () -> Content
    
    /// Creates a view that measures the performance of its `content`.
    ///
    /// - Parameter viewName: The name that will be used for the span, if nil we try to get the name of the content class.
    /// - Parameter waitForFullDisplay: Indicates whether this view transaction should wait for `SentrySDK.reportFullyDisplayed()`
    /// in case you need to track some asynchronous task. This is ignored for any `SentryTracedView` that is child of another `SentryTracedView`.
    /// If nil, it will use the `enableTimeToFullDisplayTracing` option from the SDK.
    /// - Parameter content: The content that you want to track the performance
    public init(_ viewName: String? = nil, waitForFullDisplay: Bool? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        let name = viewName ?? SentryTracedView.extractName(content: Content.self)
        let nameSource = viewName == nil ? SentryTransactionNameSource.component : SentryTransactionNameSource.custom
        let initialViewModel = SentryTraceViewModel(name: name, nameSource: nameSource, waitForFullDisplay: waitForFullDisplay)
        _viewModel = State(initialValue: initialViewModel)
    }
    
    private static func extractName(content: Any) -> String {
        var result = String(describing: content)
        
        if let index = result.firstIndex(of: "<") {
            result = String(result[result.startIndex ..< index])
        }
        
        return result
    }
    
    /// nodoc
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

/// nodoc
@available(iOS 15.0, tvOS 15.0, *)
public extension View {
    /// Wraps this view in a `SentryTracedView` to measure its performance and send the result as a transaction to Sentry.
    ///
    /// - Parameters:
    ///   - viewName: The name that will be used for the span. If nil, the name of the view type is used.
    ///   - waitForFullDisplay: Indicates whether this view transaction should wait for `SentrySDK.reportFullyDisplayed()`
    ///     in case you need to track some asynchronous task. If nil, it will use the `enableTimeToFullDisplayTracing` option from the SDK.
    /// - Returns: A view wrapped in `SentryTracedView` for performance tracking.
    func sentryTrace(_ viewName: String? = nil, waitForFullDisplay: Bool? = nil) -> some View {
        return SentryTracedView(viewName, waitForFullDisplay: waitForFullDisplay) {
            return self
        }
    }
}
#endif
