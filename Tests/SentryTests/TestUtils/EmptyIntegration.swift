#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#endif
import Foundation

class EmptyIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: Options) -> Bool {
        return true
    }
    
    func uninstall() {
        
    }
}
