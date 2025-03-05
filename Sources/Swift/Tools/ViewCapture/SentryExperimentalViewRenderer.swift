#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import UIKit

@objcMembers
class SentryExperimentalViewRenderer: NSObject, SentryViewRenderer {
    func render(view: UIView) -> UIImage {
        let scale = (view as? UIWindow ?? view.window)?.screen.scale ?? 1
        let image = SentryGraphicsImageRenderer(size: view.bounds.size, scale: scale).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        return image
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
