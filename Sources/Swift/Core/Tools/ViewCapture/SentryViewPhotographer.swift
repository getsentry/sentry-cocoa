#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

@objcMembers
@_spi(Private) public class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    private let redactBuilder: SentryUIRedactBuilder
    private let maskRenderer: SentryMaskRenderer
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: SentryViewRenderer

    /// Creates a view photographer used to convert a view hierarchy to an image.
    ///
    /// - Parameters:
    ///   - renderer: Implementation of the view renderer.
    ///   - redactOptions: Options provided to redact sensitive information.
    ///   - enableMaskRendererV2: Flag to enable experimental view renderer.
    /// - Note: The option `enableMaskRendererV2` is an internal flag, which is not part of the public API.
    ///         Therefore, it is not part of the the `redactOptions` parameter, to not further expose it.
    public init(
        renderer: SentryViewRenderer,
        redactOptions: SentryRedactOptions,
        enableMaskRendererV2: Bool
    ) {
        self.renderer = renderer
        self.maskRenderer = enableMaskRendererV2 ? SentryMaskRendererV2() : SentryDefaultMaskRenderer()
        redactBuilder = SentryUIRedactBuilder(options: redactOptions)
        super.init()
    }

    public func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        // Define a helper variable for the size, so the view is not accessed in the async block
        let viewSize = view.bounds.size

        #if DEBUG
        if let viewDebugHierarchy = view.value(forKey: "recursiveDescription") as? String {
            let data = viewDebugHierarchy.data(using: .utf8)!
            try? data.write(to: URL(fileURLWithPath: "/tmp/workdir/0-hierarchy.txt"))
        }
        #endif

        // The redact regions are expected to be thread-safe data structures
        let redactRegions = redactBuilder.redactRegionsFor(view: view)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(redactRegions)
        try! data.write(to: URL(fileURLWithPath: "/tmp/workdir/1-regions.json"))

        // The render method is synchronous and must be called on the main thread.
        // This is because the render method accesses the view hierarchy which is managed from the main thread.
        let renderedScreenshot = renderer.render(view: view)

        try! renderedScreenshot.pngData()!.write(to: URL(fileURLWithPath: "/tmp/workdir/2-render.png"))

        dispatchQueue.dispatchAsync { [maskRenderer] in
            // The mask renderer does not need to be on the main thread.
            // Moving it to a background thread to avoid blocking the main thread, therefore reducing the performance
            // impact/lag of the user interface.
            let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redactRegions)
            try! maskedScreenshot.pngData()!.write(to: URL(fileURLWithPath: "/tmp/workdir/3-masked.png"))

            onComplete(maskedScreenshot)
        }
    }

    public func image(view: UIView) -> UIImage {
        let viewSize = view.bounds.size
        let redactRegions = redactBuilder.redactRegionsFor(view: view)
        let renderedScreenshot = renderer.render(view: view)
        let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redactRegions)

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
