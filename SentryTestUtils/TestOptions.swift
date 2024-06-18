import Foundation
import Sentry

public extension Options {
    func setIntegrations(_ integrations: [AnyClass]) {
        self.integrations = integrations.map {
            NSStringFromClass($0)
        }
    }
    
    func removeAllIntegrations() {
        self.integrations = []
    }
    
    static func noIntegrations() -> Options {
        let options = Options()
        options.removeAllIntegrations()
        return options
    }
}
