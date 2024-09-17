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
    func replayRedact() -> some View {
        return SentryReplayView(replayBehaviour: .redact) {
            self
        }.fixedSize()
    }
}
