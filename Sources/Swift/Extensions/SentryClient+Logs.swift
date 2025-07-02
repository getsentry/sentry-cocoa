import Foundation

extension SentryClient {
    
    func capture(log: SentryLog, with scope: Scope) {
        do {
            // TODO: Batching
            let envelope = try SentryEnvelope(logs: [log])
            capture(envelope)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
} 
