#if SDK_V10
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCDataCollectionKeyValueCollectionBehavior)
public final class SentryObjCDataCollectionKeyValueCollectionBehavior: NSObject {
    private let box: Box<SentryDataCollection.KeyValueCollectionBehavior>

    internal var wrapped: SentryDataCollection.KeyValueCollectionBehavior {
        box.value
    }

    internal init(_ wrapped: SentryDataCollection.KeyValueCollectionBehavior) {
        self.box = Box(wrapped)
    }

    @objc public var mode: SentryObjCDataCollectionKeyValueCollectionMode {
        switch box.value {
        case .off: return .off
        case .denyList: return .denyList
        case .allowList: return .allowList
        @unknown default: return .off
        }
    }

    @objc public var terms: [String] {
        switch box.value {
        case .off: return []
        case .denyList(let terms): return terms
        case .allowList(let terms): return terms
        @unknown default: return []
        }
    }

    @objc public static func off() -> SentryObjCDataCollectionKeyValueCollectionBehavior {
        SentryObjCDataCollectionKeyValueCollectionBehavior(.off)
    }

    @objc public static func denyList(withTerms terms: [String]) -> SentryObjCDataCollectionKeyValueCollectionBehavior {
        SentryObjCDataCollectionKeyValueCollectionBehavior(.denyList(terms: terms))
    }

    @objc public static func denyList() -> SentryObjCDataCollectionKeyValueCollectionBehavior {
        SentryObjCDataCollectionKeyValueCollectionBehavior(.denyList())
    }

    @objc public static func allowList(withTerms terms: [String]) -> SentryObjCDataCollectionKeyValueCollectionBehavior {
        SentryObjCDataCollectionKeyValueCollectionBehavior(.allowList(terms: terms))
    }
}

// swiftlint:enable missing_docs
#endif // SDK_V10
