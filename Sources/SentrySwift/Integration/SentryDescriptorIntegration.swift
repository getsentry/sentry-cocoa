import Foundation

@objc
public class SentryDescriptorIntegration: NSObject, SentryIntegrationProtocol {
    
    let descriptor = SwiftDescriptor()

    @objc
    public func install(with options: Options) -> Bool {
        SentryDependencyContainer.sharedInstance.register(SentryDescriptorProtocol.self) {
            return self.descriptor
        }
        return true
    }
}
