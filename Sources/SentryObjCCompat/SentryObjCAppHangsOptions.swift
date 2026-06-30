// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCAppHangsOptions) public final class SentryObjCAppHangsOptions: NSObject {
    private let parent: SentryExperimentalOptions

    internal init(_ parent: SentryExperimentalOptions) {
        self.parent = parent
    }

    @objc public override init() {
        self.parent = SentryExperimentalOptions()
    }

    @objc public var enableV3: Bool {
        get { parent.appHangs.enableV3 }
        set { parent.appHangs.enableV3 = newValue }
    }

    @objc public var threshold: TimeInterval {
        get { parent.appHangs.threshold }
        set { parent.appHangs.threshold = newValue }
    }
}

// swiftlint:enable missing_docs
