#if canImport(SwiftUI) && canImport(UIKit) && !os(watchOS)
import Sentry
import SwiftUI
import UIKit

@available(iOS 13, macOS 10.15, tvOS 13, *)
struct SentryReplayView: UIViewRepresentable {
    class SentryRedactView: UIView {
    }
    
    func makeUIView(context: Context) -> UIView {
        let result = SentryRedactView()
        result.sentryReplayRedact()
        return result
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // This is blank on purpose. UIViewRepresentable requires this function.
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, *)
struct SentryReplayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SentryReplayView())
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, *)
public extension View {
    
    /// Marks the view as containing sensitive information that should be redacted during replays.
    ///
    /// When this modifier is applied, any sensitive content within the view will be hidden or masked
    /// during session replays to ensure user privacy. This is useful for views containing personal
    /// data or confidential information that shouldn't be visible when the replay is reviewed.
    ///
    /// - Returns: A modifier that redacts sensitive information during session replays.
    /// - Experiment: This is an experimental feature and may still have bugs.
    func sentryReplayRedact() -> some View {
        modifier(SentryReplayModifier())
    }
}
#endif
