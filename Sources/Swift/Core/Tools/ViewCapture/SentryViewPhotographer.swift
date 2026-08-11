// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

internal import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

/// Timing data for each phase of screenshot capture.
@_spi(Private) public final class SentryViewPhotographerScreenshotMetadata: NSObject {
    public let redactDuration: TimeInterval
    public let renderDuration: TimeInterval
    public let maskDuration: TimeInterval

    public init(redactDuration: TimeInterval, renderDuration: TimeInterval, maskDuration: TimeInterval) {
        self.redactDuration = redactDuration
        self.renderDuration = renderDuration
        self.maskDuration = maskDuration
        super.init()
    }

    public var mainThreadDuration: TimeInterval {
        redactDuration + renderDuration
    }
}

@objcMembers
@_spi(Private) public class SentryViewPhotographer: NSObject, SentryTimedViewScreenshotProvider {

    private let redactBuilder: SentryUIRedactBuilder
    private let maskRenderer: SentryMaskRenderer
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: SentryViewRenderer

    /// Creates a view photographer used to convert a view hierarchy to an image.
    ///
    /// - Parameters:
    ///   - renderer: Implementation of the view renderer.
    ///   - redactOptions: Options provided to redact sensitive information.
    ///   - enableMaskRendererV2: Flag to enable experimental view renderer.
    ///   - dateProvider: Source for measuring capture phase durations.
    /// - Note: The option `enableMaskRendererV2` is an internal flag, which is not part of the public API.
    ///         Therefore, it is not part of the `redactOptions` parameter, to not further expose it.
    public init(
        renderer: SentryViewRenderer,
        redactOptions: SentryRedactOptions,
        enableMaskRendererV2: Bool,
        dateProvider: SentryCurrentDateProvider = SentryDefaultCurrentDateProvider()
    ) {
        self.renderer = renderer
        self.maskRenderer = enableMaskRendererV2 ? SentryMaskRendererV2() : SentryDefaultMaskRenderer()
        self.dateProvider = dateProvider
        redactBuilder = SentryUIRedactBuilder(options: redactOptions)
        super.init()
    }

    public func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        timedImage(view: view) { screenshot, _ in
            onComplete(screenshot)
        }
    }

    public func timedImage(view: UIView, onComplete: @escaping TimedScreenshotCallback) {
        // Define a helper variable for the size, so the view is not accessed in the async block
        let viewSize = view.bounds.size

        let redactStart = dateProvider.getAbsoluteTime()
        // The redact regions are expected to be thread-safe data structures
        let redactRegions = redactBuilder.redactRegionsFor(view: view)
        let redactEnd = dateProvider.getAbsoluteTime()

        // The render method is synchronous and must be called on the main thread.
        // This is because the render method accesses the view hierarchy which is managed from the main thread.
        let renderedScreenshot = renderer.render(view: view)
        let renderEnd = dateProvider.getAbsoluteTime()

        dispatchQueue.dispatchAsync { [dateProvider, maskRenderer] in
            // The mask renderer does not need to be on the main thread.
            // Moving it to a background thread to avoid blocking the main thread, therefore reducing the performance
            // impact/lag of the user interface.
            let maskStart = dateProvider.getAbsoluteTime()
            let maskedScreenshot = maskRenderer.maskScreenshot(screenshot: renderedScreenshot, size: viewSize, masking: redactRegions)
            let maskEnd = dateProvider.getAbsoluteTime()

            let metadata = SentryViewPhotographerScreenshotMetadata(
                redactDuration: Self.duration(from: redactStart, to: redactEnd),
                renderDuration: Self.duration(from: redactEnd, to: renderEnd),
                maskDuration: Self.duration(from: maskStart, to: maskEnd)
            )
            onComplete(maskedScreenshot, metadata)
        }
    }

    private static func duration(from start: UInt64, to end: UInt64) -> TimeInterval {
        guard end >= start else { return 0 }
        return TimeInterval(end - start) / TimeInterval(NSEC_PER_SEC)
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
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
