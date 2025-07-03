@_implementationOnly import _SentryPrivate
import Foundation

extension SentryEnvelope {
    
    convenience init(logs: [SentryLog]) throws {
        let payload = ["items": logs]
        let data = try encodeToJSONData(data: payload)
        
        let header = SentryEnvelopeItemHeader(
            type: "log",
            length: UInt(data.count),
            contentType: "application/vnd.sentry.items.log+json",
            itemCount: NSNumber(value: logs.count)
        )
        // TODO: Add SDKInfo to header...
        let envelopeItem = SentryEnvelopeItem(header: header, data: data)
        self.init(id: nil, singleItem: envelopeItem)
    }
}
