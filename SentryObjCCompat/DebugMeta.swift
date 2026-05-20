internal import SentrySwift
import Foundation

/// Metadata describing a loaded debug image / library.
@objc(SOCSentryDebugMeta)
public final class DebugMeta: NSObject {
    internal let wrapped: SentrySwift.DebugMeta

    internal init(_ wrapped: SentrySwift.DebugMeta) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public override init() {
        self.wrapped = SentrySwift.DebugMeta()
        super.init()
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
