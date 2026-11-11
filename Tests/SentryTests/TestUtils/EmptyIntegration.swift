#if SWIFT_PACKAGE && !SDK_V10
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
