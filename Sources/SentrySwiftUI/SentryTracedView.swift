import Foundation
import Sentry
import SwiftUI
#if SWIFT_PACKAGE
import SentryInternal
#endif

/// - warning: This is an experimental feature and may still have bugs.
///
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
    
    let traceOrigin = "auto.ui.swift_ui"

    public init(_ viewName: String? = nil, content: @escaping () -> Content) {
        self.content = content
        self.name = viewName ?? SentryTracedView.extractName(content: Content.self)
        self.nameSource = viewName == nil ? .component : .custom
    }

    private static func extractName(content: Any) -> String {
        var result = String(describing: content)

        if let index = result.firstIndex(of: "<") {
            result = String(result[result.startIndex ..< index])
        }

        return result
    }

    public var body: some View {
        if viewAppeared {
            return self.content().onAppear()
        }

        var transactionCreated = false
        if SentryPerformanceTracker.shared.activeSpanId() == nil {
            transactionCreated = true
            let transactionId = SentryPerformanceTracker.shared.startSpan(withName: self.name, nameSource: nameSource, operation: "ui.load", origin: self.traceOrigin)
            SentryPerformanceTracker.shared.pushActiveSpan(transactionId)

            //According to Apple's documentation, the call to `body` needs to be fast
            //and can be made many times in one frame. Therefore they don't use async code to process the view.
            //Scheduling to finish the transaction at the end of the main loop seems the least hack solution right now.
            //'onAppear' is not a suitable place to do this because it may happen before other view `body` property get called.
            DispatchQueue.main.async {
                SentryPerformanceTracker.shared.popActiveSpan()
                SentryPerformanceTracker.shared.finishSpan(transactionId)
            }
        }

        let id = SentryPerformanceTracker.shared.startSpan(withName: transactionCreated ? "\(self.name) - body" : self.name, nameSource: nameSource, operation: "ui.load", origin: self.traceOrigin)

        SentryPerformanceTracker.shared.pushActiveSpan(id)
        defer {
            SentryPerformanceTracker.shared.popActiveSpan()
            SentryPerformanceTracker.shared.finishSpan(id)
        }

        return self.content().onAppear {
            self.viewAppeared = true
        }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    /// - warning: This is an experimental feature and may still have bugs.
    func sentryTrace(_ viewName: String? = nil) -> some View {
        return SentryTracedView(viewName) {
            return self
        }
    }
}
