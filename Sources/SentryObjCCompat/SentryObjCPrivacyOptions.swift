#if SDK_V10 && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCPrivacyOptions) public final class SentryObjCPrivacyOptions: NSObject {
    private let storage: Accessor<SentryPrivacyOptions>

    internal var wrapped: SentryPrivacyOptions {
        get { storage.value }
        set { storage.value = newValue }
    }

    internal init(parent: Options) {
        self.storage = Accessor(root: parent, keyPath: \.privacy)
    }

    @objc public override init() {
        self.storage = Accessor(SentryPrivacyOptions())
    }

    @objc public var maskAllText: Bool {
        get { wrapped.maskAllText }
        set { wrapped.maskAllText = newValue }
    }

    @objc public var maskAllImages: Bool {
        get { wrapped.maskAllImages }
        set { wrapped.maskAllImages = newValue }
    }

    @objc public var maskedViewClasses: [AnyClass] {
        get { wrapped.maskedViewClasses }
        set { wrapped.maskedViewClasses = newValue }
    }

    @objc public var unmaskedViewClasses: [AnyClass] {
        get { wrapped.unmaskedViewClasses }
        set { wrapped.unmaskedViewClasses = newValue }
    }

    @objc public var excludedViewClasses: Set<String> { wrapped.excludedViewClasses }
    @objc public var includedViewClasses: Set<String> { wrapped.includedViewClasses }

    @objc public func excludeViewTypeFromSubtreeTraversal(_ viewType: String) {
        wrapped.excludeViewTypeFromSubtreeTraversal(viewType)
    }

    @objc public func includeViewTypeInSubtreeTraversal(_ viewType: String) {
        wrapped.includeViewTypeInSubtreeTraversal(viewType)
    }
}
// swiftlint:enable missing_docs
#endif // SDK_V10 && UI platforms
