#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    private let redactBuilder: UIRedactBuilder
    private let maskRenderer: SentryMaskRenderer
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: SentryViewRenderer

    init(
        renderer: SentryViewRenderer,
        redactOptions: SentryRedactOptions
    ) {
        self.renderer = renderer
        self.maskRenderer = SentryDefaultMaskRenderer()
        redactBuilder = UIRedactBuilder(options: redactOptions)
        super.init()
    }

    func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        let viewSize = view.bounds.size
        let redact = redactBuilder.redactRegionsFor(view: view)
        let renderedScreenshot = renderer.render(view: view)

        dispatchQueue.dispatchAsync { [maskRenderer] in
            let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redact)
            onComplete(maskedScreenshot)
        }
    }

    func image(view: UIView) -> UIImage {
        let viewSize = view.bounds.size
        let redact = redactBuilder.redactRegionsFor(view: view)
        let renderedScreenshot = renderer.render(view: view)
        let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redact)

        return maskedScreenshot
    }

    @objc(addIgnoreClasses:)
    func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }

    @objc(setIgnoreContainerClass:)
    func setIgnoreContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setIgnoreContainerClass(containerClass)
    }

    @objc(setRedactContainerClass:)
    func setRedactContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setRedactContainerClass(containerClass)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif

}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
