import Foundation

@objc public final class SentryTestResources: NSObject {
    @objc public static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: SentryTestResources.self)
        #endif
    }
}
