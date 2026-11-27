// swiftlint:disable missing_docs
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))
import UIKit

@objc(SentryObjCReplayScreenshotProvider) public protocol SentryObjCReplayScreenshotProvider: NSObjectProtocol {
    @objc(imageWithView:onComplete:) func image(view: UIView, onComplete: @escaping (UIImage) -> Void)
}

/// Hands a hybrid SDK's frames to Session Replay.
///
/// Reports no main-thread capture time: the provider delivers its frames asynchronously, and the wait
/// until it does isn't main-thread work, so it mustn't make Session Replay back off from capturing.
final class SentryObjCReplayScreenshotProviderAdapter: NSObject, SentryTimedViewScreenshotProvider {
    private let provider: SentryObjCReplayScreenshotProvider

    init(_ provider: SentryObjCReplayScreenshotProvider) {
        self.provider = provider
    }

    func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        provider.image(view: view, onComplete: onComplete)
    }

    func timedImage(view: UIView, onComplete: @escaping TimedScreenshotCallback) {
        provider.image(view: view) { image in
            onComplete(image, SentryViewPhotographerScreenshotMetadata(redactDuration: 0, renderDuration: 0, maskDuration: 0))
        }
    }
}

@objc(SentryObjCInternalReplayApi) public final class SentryObjCInternalReplayApi: NSObject {
    private let wrapped: Box<SentryInternalReplayApi>

    internal init(_ wrapped: SentryInternalReplayApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func start() {
        wrapped.value.start()
    }

    @objc public func startBuffering() {
        wrapped.value.startBuffering()
    }

    @objc public func pause() {
        wrapped.value.pause()
    }

    @objc public func resume() {
        wrapped.value.resume()
    }

    @objc public func pauseTouchTracking() {
        wrapped.value.pauseTouchTracking()
    }

    @objc public func resumeTouchTracking() {
        wrapped.value.resumeTouchTracking()
    }

    @objc public func flush() {
        wrapped.value.flush()
    }

    @objc public func stop() {
        wrapped.value.stop()
    }

    @objc public func setScreenshotProvider(_ provider: SentryObjCReplayScreenshotProvider) {
        let adapter = SentryObjCReplayScreenshotProviderAdapter(provider)
        wrapped.value.configure(breadcrumbConverter: nil, screenshotProvider: adapter)
    }

    @objc public func capture() -> Bool {
        wrapped.value.capture()
    }

    @objc public var replayId: String? {
        wrapped.value.replayId
    }

    @objc public func addIgnoreClasses(_ classes: [AnyClass]) {
        wrapped.value.addIgnoreClasses(classes)
    }

    @objc public func addRedactClasses(_ classes: [AnyClass]) {
        wrapped.value.addRedactClasses(classes)
    }

    @objc public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        wrapped.value.setIgnoreContainerClass(containerClass)
    }

    @objc public func setRedactContainerClass(_ containerClass: AnyClass) {
        wrapped.value.setRedactContainerClass(containerClass)
    }

    @objc public func setTags(_ tags: [String: Any]) {
        wrapped.value.setTags(tags)
    }

    @objc public func registerTraceId(_ traceId: SentryObjCId) {
        wrapped.value.registerTraceId(traceId.wrapped)
    }
}

#endif
// swiftlint:enable missing_docs
