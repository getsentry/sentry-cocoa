#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

public extension UIView {
    
    /**
     * Marks this view to be redacted during replays.
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryReplayMask() {
        SentryRedactViewHelper.maskView(self)
    }
    
    /**
     * Marks this view to be ignored during redact step
     * of session replay. All its content will be visible in the replay.
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryReplayUnmask() {
        SentryRedactViewHelper.unmaskView(self)
    }
    
    /**
     * Marks this view to create a region in the session replay
     * where nothing behind it will be masked.
     * This can be used to unmask non PII region inside SwiftUI
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryReplayClipOut() {
        SentryRedactViewHelper.clipOutView(self)
    }
    
    /**
     * Marks this view as comming from SwiftUI and needs to be redacted.
     * - experiment:  This is an experimental feature and may still have bugs.
     */
    func sentryReplayMaskSwiftUI() {
        SentryRedactViewHelper.maskSwiftUI(self)
    }
}

#endif
#endif
