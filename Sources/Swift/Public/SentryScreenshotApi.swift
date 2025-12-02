#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import Foundation
import UIKit

/**
 * API to control screenshot masking.
 */
@objcMembers
public final class SentryScreenshotApi: NSObject {
    
    /**
     * Marks this view to be masked during screenshots.
     */
    @objc(maskView:)
    public func maskView(_ view: UIView) {
        SentryRedactViewHelper.maskView(view)
    }
    
    /**
     * Marks this view to not be masked during screenshot masking.
     */
    @objc(unmaskView:)
    public func unmaskView(_ view: UIView) {
        SentryRedactViewHelper.unmaskView(view)
    }
    
    /**
     * Shows an overlay on the app to debug screenshot masking.
     *
     * By calling this function an overlay will appear covering the parts
     * of the app that will be masked for screenshots.
     * This will only work if the debugger is attached and it will
     * cause some slow frames.
     *
     * - note: This method must be called from the main thread.
     *
     * - warning: This is an experimental feature and may still have bugs.
     * Do not use this in production.
     */
    @objc(showMaskPreview)
    public func showMaskPreview() {
        showMaskPreview(opacity: 1.0)
    }
    
    /**
     * Shows an overlay on the app to debug screenshot masking.
     *
     * By calling this function an overlay will appear covering the parts
     * of the app that will be masked for screenshots.
     * This will only work if the debugger is attached and it will
     * cause some slow frames.
     *
     * - parameter opacity: The opacity of the overlay.
     *
     * - note: This method must be called from the main thread.
     *
     * - warning: This is an experimental feature and may still have bugs.
     * Do not use this in production.
     */
    @objc(showMaskPreviewWithOpacity:)
    public func showMaskPreview(opacity: CGFloat) {
        SentrySDKLog.debug("[Screenshot] Showing mask preview with opacity: \(opacity)")
        // Use Objective-C runtime to get the integration class since it's not directly accessible from Swift
        guard let integrationClass = NSClassFromString("SentryScreenshotIntegration") as? NSObject.Type else {
            SentrySDKLog.debug("[Screenshot] Screenshot integration class not found")
            return
        }
        guard let screenshotIntegration = SentrySDKInternal.currentHub()
            .getInstalledIntegration(integrationClass) else {
            SentrySDKLog.debug("[Screenshot] Screenshot integration not installed")
            return
        }
        
        // Use performSelector to call the Objective-C method
        let selector = NSSelectorFromString("showMaskPreview:")
        if screenshotIntegration.responds(to: selector) {
            screenshotIntegration.perform(selector, with: opacity)
        }
    }
    
    /**
     * Removes the overlay that shows screenshot masking.
     *
     * - note: This method must be called from the main thread.
     *
     * - warning: This is an experimental feature and may still have bugs.
     * Do not use this in production.
     */
    @objc(hideMaskPreview)
    public func hideMaskPreview() {
        SentrySDKLog.debug("[Screenshot] Hiding mask preview")
        // Use Objective-C runtime to get the integration class since it's not directly accessible from Swift
        guard let integrationClass = NSClassFromString("SentryScreenshotIntegration") as? NSObject.Type else {
            SentrySDKLog.debug("[Screenshot] Screenshot integration class not found")
            return
        }
        guard let screenshotIntegration = SentrySDKInternal.currentHub()
            .getInstalledIntegration(integrationClass) else {
            SentrySDKLog.debug("[Screenshot] Screenshot integration not installed")
            return
        }
        
        // Use performSelector to call the Objective-C method
        let selector = NSSelectorFromString("hideMaskPreview")
        if screenshotIntegration.responds(to: selector) {
            screenshotIntegration.perform(selector)
        }
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
