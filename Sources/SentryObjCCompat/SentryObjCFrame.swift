// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCFrame: NSObject {
    internal let wrapped: Frame

    internal init(_ wrapped: Frame) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = Frame()
    }

    @objc public var symbolAddress: String? {
        get { wrapped.symbolAddress }
        set { wrapped.symbolAddress = newValue }
    }

    @objc public var fileName: String? {
        get { wrapped.fileName }
        set { wrapped.fileName = newValue }
    }

    @objc public var function: String? {
        get { wrapped.function }
        set { wrapped.function = newValue }
    }

    @objc public var module: String? {
        get { wrapped.module }
        set { wrapped.module = newValue }
    }

    @objc public var package: String? {
        get { wrapped.package }
        set { wrapped.package = newValue }
    }

    @objc public var imageAddress: String? {
        get { wrapped.imageAddress }
        set { wrapped.imageAddress = newValue }
    }

    @objc public var platform: String? {
        get { wrapped.platform }
        set { wrapped.platform = newValue }
    }

    @objc public var instructionAddress: String? {
        get { wrapped.instructionAddress }
        set { wrapped.instructionAddress = newValue }
    }

    @objc public var lineNumber: NSNumber? {
        get { wrapped.lineNumber }
        set { wrapped.lineNumber = newValue }
    }

    @objc public var columnNumber: NSNumber? {
        get { wrapped.columnNumber }
        set { wrapped.columnNumber = newValue }
    }

    @objc public var contextLine: String? {
        get { wrapped.contextLine }
        set { wrapped.contextLine = newValue }
    }

    @objc public var parentIndex: NSNumber? {
        get { wrapped.parentIndex }
        set { wrapped.parentIndex = newValue }
    }

    @objc public var sampleCount: NSNumber? {
        get { wrapped.sampleCount }
        set { wrapped.sampleCount = newValue }
    }

    @objc public var preContext: [String]? {
        get { wrapped.preContext }
        set { wrapped.preContext = newValue }
    }

    @objc public var postContext: [String]? {
        get { wrapped.postContext }
        set { wrapped.postContext = newValue }
    }

    @objc public var inApp: NSNumber? {
        get { wrapped.inApp }
        set { wrapped.inApp = newValue }
    }

    @objc public var stackStart: NSNumber? {
        get { wrapped.stackStart }
        set { wrapped.stackStart = newValue }
    }

    @objc public var vars: [String: Any]? {
        get { wrapped.vars }
        set { wrapped.vars = newValue }
    }
}

// swiftlint:enable missing_docs
