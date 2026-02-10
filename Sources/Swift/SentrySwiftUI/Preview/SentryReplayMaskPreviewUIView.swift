#if canImport(SwiftUI) && canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
import UIKit

@_implementationOnly import _SentryPrivate

class SentryReplayMaskPreviewUIView: UIView {
    
    private let maskingOverlay: UIView
    
    var opacity: CGFloat {
        get { maskingOverlay.alpha }
        set { maskingOverlay.alpha = newValue }
    }
    
    init(redactOptions: SentryRedactOptions) {
        maskingOverlay = PrivateSentrySDKOnly.sessionReplayMaskingOverlay(redactOptions)
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window = self.window else { return }
        maskingOverlay.frame = window.bounds
        window.addSubview(maskingOverlay)
    }
}

#endif
