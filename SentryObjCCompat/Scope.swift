internal import SentrySwift
import Foundation

/// Contextual data attached to every captured event.
@objc(SOCSentryScope)
public final class Scope: NSObject {
    internal let wrapped: SentrySwift.Scope

    internal init(_ wrapped: SentrySwift.Scope) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(maxBreadcrumbs: Int) {
        self.wrapped = SentrySwift.Scope(maxBreadcrumbs: maxBreadcrumbs)
        super.init()
    }

    @objc public override init() {
        self.wrapped = SentrySwift.Scope()
        super.init()
    }

    @objc public init(scope: Scope) {
        self.wrapped = SentrySwift.Scope(scope: scope.wrapped)
        super.init()
    }

    @objc public var span: Span? {
        get { wrapped.span.map { Span($0) } }
        set { wrapped.span = newValue?.wrapped }
    }

    @objc public var replayId: String? {
        get { wrapped.replayId }
        set { wrapped.replayId = newValue }
    }

    @objc public var tags: [String: String] { wrapped.tags }
    @objc public var attributes: [String: Any] { wrapped.attributes }

    @objc public func setUser(_ user: User?) {
        wrapped.setUser(user?.wrapped)
    }

    @objc(setTagValue:forKey:)
    public func setTag(value: String, key: String) {
        wrapped.setTag(value: value, key: key)
    }

    @objc(removeTagForKey:)
    public func removeTag(key: String) {
        wrapped.removeTag(key: key)
    }

    @objc public func setTags(_ tags: [String: String]?) {
        wrapped.setTags(tags)
    }

    @objc public func setExtras(_ extras: [String: Any]?) {
        wrapped.setExtras(extras)
    }

    @objc(setExtraValue:forKey:)
    public func setExtra(value: Any?, key: String) {
        wrapped.setExtra(value: value, key: key)
    }

    @objc(removeExtraForKey:)
    public func removeExtra(key: String) {
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

    @objc public func setLevel(_ level: SentryLevel) {
        wrapped.setLevel(level.underlying)
    }

    @objc(addBreadcrumb:)
    public func addBreadcrumb(_ crumb: Breadcrumb) {
        wrapped.addBreadcrumb(crumb.wrapped)
    }

    @objc public func clearBreadcrumbs() {
        wrapped.clearBreadcrumbs()
    }

    @objc(setContextValue:forKey:)
    public func setContext(value: [String: Any], key: String) {
        wrapped.setContext(value: value, key: key)
    }

    @objc(removeContextForKey:)
    public func removeContext(key: String) {
        wrapped.removeContext(key: key)
    }

    @objc(addAttachment:)
    public func addAttachment(_ attachment: Attachment) {
        wrapped.addAttachment(attachment.wrapped)
    }

    @objc(setAttributeValue:forKey:)
    public func setAttribute(value: Any, key: String) {
        wrapped.setAttribute(value: value, key: key)
    }

    @objc(removeAttributeForKey:)
    public func removeAttribute(key: String) {
        wrapped.removeAttribute(key: key)
    }

    @objc public func clearAttachments() {
        wrapped.clearAttachments()
    }

    @objc public func clear() {
        wrapped.clear()
    }
}
