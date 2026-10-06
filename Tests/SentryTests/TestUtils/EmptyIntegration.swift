#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#endif
import Foundation

class EmptyIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: Options) -> Bool {
        return true
    }
    
    func uninstall() {
        
    }
}
