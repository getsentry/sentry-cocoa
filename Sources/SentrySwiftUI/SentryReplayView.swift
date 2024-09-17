import SwiftUI
import UIKit
import Sentry

public enum ReplayBehaviour {
    case redact
    case ignore
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
struct SentryReplayView<Content: View>: UIViewRepresentable {
    
    public let content: () -> Content
    public let replayBehaviour: ReplayBehaviour
    
    public init(replayBehaviour: ReplayBehaviour = .redact, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.replayBehaviour = replayBehaviour
    }
    
    public func makeUIView(context: Context) -> UIView {
        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = .clear
        return hostingController.view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        switch replayBehaviour {
            case .ignore: uiView.sentryReplayIgnore()
            case .redact: uiView.sentryReplayRedact()
        }
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
        return SentryReplayView(replayBehaviour: .redact) {
            self
        }.fixedSize() //We use `fixedSize` to make SentryReplayView only wrap its content and not used all available space
    }
}
