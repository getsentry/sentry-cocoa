// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS) || os(visionOS)

import UIKit

final class SentryViewRendererV2: NSObject, SentryViewRenderer {
    let enableFastViewRendering: Bool

    init(enableFastViewRendering: Bool) {
        self.enableFastViewRendering = enableFastViewRendering
    }

    func render(view: UIView) -> UIImage {
        #if os(visionOS)
        let scale = view.traitCollection.displayScale > 0 ? view.traitCollection.displayScale : 1
        #else
        let scale = (view as? UIWindow ?? view.window)?.screen.scale ?? 1
        #endif
        let image = SentryGraphicsImageRenderer(size: view.bounds.size, scale: scale).image { context in
            if enableFastViewRendering {
                view.layer.render(in: context.cgContext)
            } else {
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
        }
        return image
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
