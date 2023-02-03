import Foundation
import Sentry
import SwiftUI
#if SWIFT_PACKAGE
import SentryInternal
#endif

///
/// This feature is EXPERIMENTAL.
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

    @State var viewWasPresented = false

    let content: () -> Content
    let name: String
    let nameSource : SentryTransactionNameSource

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
        if viewWasPresented  {
            return self.content().onAppear()
        }

        let id = SentryPerformanceTracker.shared.startSpan(withName: self.name, nameSource: self.nameSource, operation: "ui.load")

        SentryPerformanceTracker.shared.pushActiveSpan(id)
        defer {
            SentryPerformanceTracker.shared.popActiveSpan()
            SentryPerformanceTracker.shared.finishSpan(id)
        }

        return self.content().onAppear {
            self.viewWasPresented = true
        }
    }
}

///
/// This feature is EXPERIMENTAL.
///
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    func sentryTrace(_ viewName: String? = nil) -> some View {
        return SentryTracedView(viewName) {
            return self
        }
    }
}
