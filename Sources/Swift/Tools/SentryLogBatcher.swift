import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient
    
    @_spi(Private) public init(client: SentryClient) {
        self.client = client
        super.init()
    }
    
    @_spi(Private) public func processLog(_ log: SentryLog, with scope: Scope) {
        do {
            let envelope = try SentryEnvelope(logs: [log])
            client.capture(envelope)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
