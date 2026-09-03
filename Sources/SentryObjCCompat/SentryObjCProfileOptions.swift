// swiftlint:disable missing_docs
#if os(iOS) || os(macOS)
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCProfileOptions) public final class SentryObjCProfileOptions: NSObject {
    internal let wrapped: SentryProfileOptions

    internal init(_ wrapped: SentryProfileOptions) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = SentryProfileOptions()
    }

    @objc public var lifecycle: SentryObjCProfileLifecycle {
        get { SentryObjCProfileLifecycle(wrapped.lifecycle) }
        set { wrapped.lifecycle = newValue.underlying }
    }

    @objc public var sessionSampleRate: Float {
        get { wrapped.sessionSampleRate }
        set { wrapped.sessionSampleRate = newValue }
    }

    @objc public var profileAppStarts: Bool {
        get { wrapped.profileAppStarts }
        set { wrapped.profileAppStarts = newValue }
    }
}

#endif // os(iOS) || os(macOS)
// swiftlint:enable missing_docs
