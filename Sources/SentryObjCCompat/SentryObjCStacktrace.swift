// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCStacktrace) public final class SentryObjCStacktrace: NSObject {
    internal let wrapped: SentryStacktrace

    internal init(_ wrapped: SentryStacktrace) {
        self.wrapped = wrapped
    }

    @objc public init(frames: [SentryObjCFrame], registers: [String: String]) {
        self.wrapped = SentryStacktrace(frames: frames.map(\.wrapped), registers: registers)
    }

    @objc public var frames: [SentryObjCFrame] {
        get { wrapped.frames.map { SentryObjCFrame($0) } }
        set { wrapped.frames = newValue.map(\.wrapped) }
    }

    @objc public var registers: [String: String] {
        get { wrapped.registers }
        set { wrapped.registers = newValue }
    }

    @objc public var snapshot: NSNumber? {
        get { wrapped.snapshot }
        set { wrapped.snapshot = newValue }
    }
}

// swiftlint:enable missing_docs
