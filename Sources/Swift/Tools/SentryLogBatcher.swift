@_implementationOnly import _SentryPrivate
import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient
    
    @_spi(Private) public init(client: SentryClient) {
        self.client = client
        super.init()
    }
    
    @_spi(Private) public func add(_ log: SentryLog) {
        // TODO: Implement batching...
        dispatch(logs: [log])
    }
    
    private func dispatch(logs: [SentryLog]) {
        do {
            let payload = ["items": logs]
            let data = try encodeToJSONData(data: payload)
            
            let header = SentryEnvelopeItemHeader(
                type: "log",
                length: UInt(data.count),
                contentType: "application/vnd.sentry.items.log+json",
                itemCount: NSNumber(value: logs.count)
            )
            let envelopeItem = SentryEnvelopeItem(header: header, data: data)
            let envelope = SentryEnvelope(id: nil, singleItem: envelopeItem)
            client.capture(envelope)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
