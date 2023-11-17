import Foundation
import Sentry

public extension Options {
    func setIntegrations(_ integrations: [AnyClass]) {
        self.integrations = integrations.map {
            String(describing: $0)
        }
    }
    
    func removeAllIntegrations() {
        self.integrations = []
    }
}
