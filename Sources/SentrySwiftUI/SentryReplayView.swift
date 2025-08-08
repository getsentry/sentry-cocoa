#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
@_spi(Private) import Sentry
import SwiftUI
import UIKit

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
#endif

enum MaskBehavior {
    case mask
    case unmask
}

@available(iOS 13, macOS 10.15, tvOS 13, *)
struct SentryReplayView: UIViewRepresentable {
    let maskBehavior: MaskBehavior
    
    class SentryRedactView: UIView {
    }
    
    func makeUIView(context: Context) -> SentryRedactView {
        return SentryRedactView()
    }
    
    func updateUIView(_ uiView: SentryRedactView, context: Context) {
        switch maskBehavior {
            case .mask: SentryRedactViewHelper.maskSwiftUI(uiView)
            case .unmask: SentryRedactViewHelper.clipOutView(uiView)
        }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, *)
struct SentryReplayModifier: ViewModifier {
    let behavior: MaskBehavior
    func body(content: Content) -> some View {
        content.overlay(SentryReplayView(maskBehavior: behavior).disabled(true))
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, *)
public extension View {
    
    /// Marks the view as containing sensitive information that should be masked during replays.
    ///
    /// When this modifier is applied, any sensitive content within the view will be masked
    /// during session replays to ensure user privacy. This is useful for views containing personal
    /// data or confidential information that shouldn't be visible when the replay is reviewed.
    ///
    /// - Returns: A modifier that redacts sensitive information during session replays.
    /// - Experiment: This is an experimental feature and may still have bugs.
    func sentryReplayMask() -> some View {
        modifier(SentryReplayModifier(behavior: .mask))
    }
    
    /// Marks the view as safe to not be masked during session replay.
    ///
    /// Anything that is behind this view will also not be masked anymore.
    ///
    /// - Returns: A modifier that prevents a view from being masked in the session replay.
    /// - Experiment: This is an experimental feature and may still have bugs.
    func sentryReplayUnmask() -> some View {
        modifier(SentryReplayModifier(behavior: .unmask))
    }
}
#endif
