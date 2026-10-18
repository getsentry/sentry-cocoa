#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation

class EmptyIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: Options) -> Bool {
        return true
    }
    
    func uninstall() {
        
    }
}
