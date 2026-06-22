// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

@objc(SentryObjCInternalReplayApi) public final class SentryObjCInternalReplayApi: NSObject {
    private let wrapped: Box<SentryInternalReplayApi>

    internal init(_ wrapped: SentryInternalReplayApi) {
        self.wrapped = Box(wrapped)
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
}

#endif
// swiftlint:enable missing_docs
