#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS) || os(visionOS)

import UIKit

final class SentryMaskRendererV2: SentryDefaultMaskRenderer {
    override func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [SentryRedactRegion], scale: CGFloat) -> UIImage {
        let image = SentryGraphicsImageRenderer(size: size, scale: scale).image { context in
            // The experimental mask renderer only uses a different graphics renderer and can reuse the default masking logic.
            applyMasking(to: context, image: image, size: size, masking: masking)
        }
        return image
    }
}

extension SentryGraphicsImageRenderer.Context: SentryMaskRendererContext {}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
