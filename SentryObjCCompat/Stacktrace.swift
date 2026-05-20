internal import SentrySwift
import Foundation

/// A stack trace, composed of frames plus optional register state.
@objc(SOCSentryStacktrace)
public final class Stacktrace: NSObject {
    internal let wrapped: SentrySwift.SentryStacktrace

    internal init(_ wrapped: SentrySwift.SentryStacktrace) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init(frames: [Frame], registers: [String: String]) {
        self.wrapped = SentrySwift.SentryStacktrace(
            frames: frames.map { $0.wrapped },
            registers: registers
        )
        super.init()
    }

    @objc public var frames: [Frame] {
        get { wrapped.frames.map(Frame.init) }
        set { wrapped.frames = newValue.map { $0.wrapped } }
    }

    @objc public var registers: [String: String] {
        get { wrapped.registers }
        set { wrapped.registers = newValue }
    }

    @objc public var snapshot: NSNumber? {
        get { wrapped.snapshot }
        set { wrapped.snapshot = newValue }
    }

    @objc public func fixDuplicateFrames() {
        wrapped.fixDuplicateFrames()
    }
}
