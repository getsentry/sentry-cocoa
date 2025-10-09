#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

@objcMembers
@_spi(Private) public class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    private let redactBuilder: SentryUIRedactBuilderProtocol
    private let maskRenderer: SentryMaskRenderer
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: SentryViewRenderer

    /// Creates a view photographer used to convert a view hierarchy to an image.
    ///
    /// - Parameters:
    ///   - renderer: Implementation of the view renderer.
    ///   - redactBuilder: Implementation of the redact builder
    /// - Note: The option `enableMaskRendererV2` is an internal flag, which is not part of the public API.
    ///         Therefore, it is not part of the the `redactOptions` parameter, to not further expose it.
    public init(
        renderer: SentryViewRenderer,
        redactBuilder: SentryUIRedactBuilderProtocol,
        enableMaskRendererV2: Bool
    ) {
        self.renderer = renderer
        self.maskRenderer = enableMaskRendererV2 ? SentryMaskRendererV2() : SentryDefaultMaskRenderer()
        self.redactBuilder = redactBuilder
        super.init()
    }

    public func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        // Define a helper variable for the size, so the view is not accessed in the async block
        let viewSize = view.bounds.size

        // The render method is synchronous and must be called on the main thread.
        // This is because the render method accesses the view hierarchy which is managed from the main thread.
        let renderedScreenshot = renderer.render(view: view)

        // The redact regions are expected to be thread-safe data structures
        redactBuilder
            .redactRegionsFor(view: view, image: renderedScreenshot) { [dispatchQueue, maskRenderer] (redactRegions: [SentryRedactRegion]?, error: Error?) in
                if let error = error {
                    print(error)
                }
                dispatchQueue.dispatchAsync { [maskRenderer] in
                    // The mask renderer does not need to be on the main thread.
                    // Moving it to a background thread to avoid blocking the main thread, therefore reducing the performance
                    // impact/lag of the user interface.
                    let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redactRegions ?? [])

                    onComplete(maskedScreenshot)
                }
            }
    }

    public func image(view: UIView) -> UIImage {
        let viewSize = view.bounds.size
        let renderedScreenshot = renderer.render(view: view)
        let dispatchGroup = DispatchGroup()
        var redactRegions: [SentryRedactRegion]?
        redactBuilder.redactRegionsFor(view: view, image: renderedScreenshot, callback: { regions, error in
            redactRegions = regions
            dispatchGroup.leave()
        })
        dispatchGroup.enter()
        dispatchGroup.wait()
        let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redactRegions ?? [])

        return maskedScreenshot
    }

    @objc(addIgnoreClasses:)
    public func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    public func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }

    @objc(setIgnoreContainerClass:)
    public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setIgnoreContainerClass(containerClass)
    }

    @objc(setRedactContainerClass:)
    public func setRedactContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setRedactContainerClass(containerClass)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func getRedactBuilder() -> SentryUIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
