// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCScope: NSObject {
    internal let wrapped: Scope

    internal init(_ wrapped: Scope) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Scope()
    }

    @objc public init(maxBreadcrumbs: Int) {
        self.wrapped = Scope(maxBreadcrumbs: maxBreadcrumbs)
    }

    @objc public var replayId: String? {
        get { wrapped.replayId }
        set { wrapped.replayId = newValue }
    }

    @objc public var tags: [String: String] {
        wrapped.tags
    }

    @objc public var attributes: [String: Any] {
        wrapped.attributes
    }

    @objc public func setUser(_ user: SentryObjCUser?) {
        wrapped.setUser(user?.wrapped)
    }

    @objc public func setTag(value: String, key: String) {
        wrapped.setTag(value: value, key: key)
    }

    @objc public func removeTag(key: String) {
        wrapped.removeTag(key: key)
    }

    @objc public func setTags(_ tags: [String: String]?) {
        wrapped.setTags(tags)
    }

    @objc public func setExtras(_ extras: [String: Any]?) {
        wrapped.setExtras(extras)
    }

    @objc public func setExtra(value: Any?, key: String) {
        wrapped.setExtra(value: value, key: key)
    }

    @objc public func removeExtra(key: String) {
        wrapped.removeExtra(key: key)
    }

    @objc public func setDist(_ dist: String?) {
        wrapped.setDist(dist)
    }

    @objc public func setEnvironment(_ environment: String?) {
        wrapped.setEnvironment(environment)
    }

    @objc public func setFingerprint(_ fingerprint: [String]?) {
        wrapped.setFingerprint(fingerprint)
    }

    @objc public func setLevel(_ level: SentryObjCLevel) {
        wrapped.setLevel(level.underlying)
    }

    @objc public func addBreadcrumb(_ crumb: SentryObjCBreadcrumb) {
        wrapped.addBreadcrumb(crumb.wrapped)
    }

    @objc public func clearBreadcrumbs() {
        wrapped.clearBreadcrumbs()
    }

    @objc public func setContext(value: [String: Any], key: String) {
        wrapped.setContext(value: value, key: key)
    }

    @objc public func removeContext(key: String) {
        wrapped.removeContext(key: key)
    }

    @objc public func addAttachment(_ attachment: SentryObjCAttachment) {
        wrapped.addAttachment(attachment.wrapped)
    }

    @objc public func setAttribute(value: Any, key: String) {
        wrapped.setAttribute(value: value, key: key)
    }

    @objc public func removeAttribute(key: String) {
        wrapped.removeAttribute(key: key)
    }

    @objc public func clearAttachments() {
        wrapped.clearAttachments()
    }

    @objc public func clear() {
        wrapped.clear()
    }
}

// swiftlint:enable missing_docs
