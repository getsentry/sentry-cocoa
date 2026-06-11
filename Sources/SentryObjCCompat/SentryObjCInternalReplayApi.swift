// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalReplayApi) public final class SentryObjCInternalReplayApi: NSObject {
    internal let wrapped: SentryInternalReplayApi

    internal init(_ wrapped: SentryInternalReplayApi) {
        self.wrapped = wrapped
    }

    @objc @discardableResult public func capture() -> Bool {
        wrapped.capture()
    }

    @objc public var replayId: String? {
        wrapped.replayId
    }

    @objc public func addIgnoreClasses(_ classes: [AnyClass]) {
        wrapped.addIgnoreClasses(classes)
    }

    @objc public func addRedactClasses(_ classes: [AnyClass]) {
        wrapped.addRedactClasses(classes)
    }

    @objc public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        wrapped.setIgnoreContainerClass(containerClass)
    }

    @objc public func setRedactContainerClass(_ containerClass: AnyClass) {
        wrapped.setRedactContainerClass(containerClass)
    }

    @objc public func setTags(_ tags: [String: Any]) {
        wrapped.setTags(tags)
    }
}

#endif
// swiftlint:enable missing_docs
