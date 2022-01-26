import Foundation

class TestSentryIntegrationProvider: SentryIntegrationProvider {
    
    var integrations = Options().integrations ?? []
    
    override var enabledIntegrations: [String] {
        return integrations
    }
    
}
