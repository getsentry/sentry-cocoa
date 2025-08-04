import Foundation
import Sentry

public extension Options {
    @available(*, deprecated)
    func setIntegrations(_ integrations: [AnyClass]) {
        self.integrations = integrations.map {
            NSStringFromClass($0)
        }
    }
    
    @available(*, deprecated)
    func removeAllIntegrations() {
        self.integrations = []
    }
    
    @available(*, deprecated)
    static func noIntegrations() -> Options {
        let options = Options()
        options.removeAllIntegrations()
        return options
    }
}
