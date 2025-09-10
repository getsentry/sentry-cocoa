#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

public extension UIView {
    
    /**
     * Marks this view to be redacted during screenshot capturing.
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryScreenshotMask() {
        SentryRedactViewHelper.maskView(self)
    }
    
    /**
     * Marks this view to be ignored during redact step
     * of screenshot capturing. All its content will be visible in the replay.
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryScreenshotUnmask() {
        SentryRedactViewHelper.unmaskView(self)
    }
}

#endif
#endif
