// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public final class SentryObjCDebugMeta: NSObject {
    internal let wrapped: DebugMeta

    internal init(_ wrapped: DebugMeta) {
        self.wrapped = wrapped
    }

    @objc public override init() {
        self.wrapped = DebugMeta()
    }

    @objc public var debugID: String? {
        get { wrapped.debugID }
        set { wrapped.debugID = newValue }
    }

    @objc public var type: String? {
        get { wrapped.type }
        set { wrapped.type = newValue }
    }

    @objc public var imageSize: NSNumber? {
        get { wrapped.imageSize }
        set { wrapped.imageSize = newValue }
    }

    @objc public var imageAddress: String? {
        get { wrapped.imageAddress }
        set { wrapped.imageAddress = newValue }
    }

    @objc public var imageVmAddress: String? {
        get { wrapped.imageVmAddress }
        set { wrapped.imageVmAddress = newValue }
    }

    @objc public var codeFile: String? {
        get { wrapped.codeFile }
        set { wrapped.codeFile = newValue }
    }
}

// swiftlint:enable missing_docs
