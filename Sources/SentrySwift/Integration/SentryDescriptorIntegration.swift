import Foundation
import SentryObjc

public class SentryDescriptorIntegration: NSObject, SentryIntegrationProtocol {
    
    let descriptor = SwiftDescriptor()
    
    public func install(with options: Options) -> Bool {
        SentryDependencyContainer.sharedInstance.register(SentryDescriptorProtocol.self) {
            return self.descriptor
        }
        return true
    }
}
