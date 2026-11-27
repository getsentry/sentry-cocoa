// swiftlint:disable missing_docs
internal import Sentry
import Foundation

@objc(SentryObjCBaggage) public final class SentryObjCBaggage: NSObject {
    private override init() {
        super.init()
    }

    @objc public static var httpHeaderField: String {
        Baggage.httpHeaderField
    }
}

// swiftlint:enable missing_docs
