#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
import Sentry
import SwiftUI
import UIKit

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
#endif

struct SentryReplayMaskPreview: ViewModifier {
    let redactOptions: SentryRedactOptions
    let opacity: Float
    func body(content: Content) -> some View {
        content.overlay(SentryReplayPreviewView(redactOptions: redactOptions, opacity: opacity).disabled(true))
    }
}

public extension View {
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
