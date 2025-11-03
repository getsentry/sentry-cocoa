import Foundation

class EmptyIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: SentryOptionsInternal) -> Bool {
        return true
    }
    
    func uninstall() {
        
    }
}
