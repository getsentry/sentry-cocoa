import Sentry
import SwiftUI
import UIKit

class SentryRedactView: UIView {
    
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
struct SentryReplayView: UIViewRepresentable {
    public func makeUIView(context: Context) -> UIView {
        let result = SentryRedactView()
        result.sentryReplayRedact()
        return result
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        // This is blank on purpose. UIViewRepresentable requires this function.
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
public extension View {
    
    /// Marks the view as containing sensitive information that should be redacted during replays.
    ///
    /// When this modifier is applied, any sensitive content within the view will be hidden or masked
    /// during session replays to ensure user privacy. This is useful for views containing personal
    /// data or confidential information that shouldn't be visible when the replay is reviewed.
    ///
    /// - Returns: A view that redacts sensitive information during session replays.
    ///
    func replayRedact() -> some View {
        self.background(
            SentryReplayView()
        )
    }
}
