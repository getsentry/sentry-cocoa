#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
import Sentry
import SwiftUI
import UIKit

@_implementationOnly import _SentryPrivate

struct SentryReplayMaskPreview: ViewModifier {
    let redactOptions: SentryRedactOptions
    let opacity: Float
    func body(content: Content) -> some View {
        content.overlay(SentryReplayPreviewView(redactOptions: redactOptions, opacity: opacity).disabled(true))
    }
}

/// nodoc
public extension View {
    /// Applies a Sentry replay mask preview overlay to this view for debugging redaction rules.
    ///
    /// This modifier shows a preview of how the view will appear in session replays with the given
    /// redaction options applied. Useful for verifying that sensitive content is properly masked.
    ///
    /// - Parameters:
    ///   - redactOptions: The redaction options to use for the preview. If nil, uses the SDK's configured session replay options.
    ///   - opacity: The opacity of the preview overlay. Defaults to 1 (fully opaque).
    /// - Returns: A view with a session replay mask preview overlay.
    func sentryReplayPreviewMask(redactOptions: SentryRedactOptions? = nil, opacity: Float = 1) -> some View {
        let options = redactOptions ?? SentrySDKInternal.options?.sessionReplay ?? PreviewRedactOptions()
        return modifier(SentryReplayMaskPreview(redactOptions: options, opacity: opacity))
    }
}

struct SentryReplayPreviewView: UIViewRepresentable {
    let redactOptions: SentryRedactOptions
    let opacity: Float
    
    func makeUIView(context: Context) -> SentryReplayMaskPreviewUIView {
        return SentryReplayMaskPreviewUIView(redactOptions: redactOptions)
    }
    
    func updateUIView(_ uiView: SentryReplayMaskPreviewUIView, context: Context) {
        uiView.opacity = CGFloat(opacity)
    }
}

#endif
