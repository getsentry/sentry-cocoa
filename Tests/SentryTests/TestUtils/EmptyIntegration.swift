import Foundation
@_spi(Private) import Sentry

class EmptyIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: Options) -> Bool {
        return true
    }
    
    func uninstall() {
        
    }
}
