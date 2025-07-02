import Foundation
@_implementationOnly import _SentryPrivate

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
        let envelopeItem = SentryEnvelopeItem(header: header, data: data)
        self.init(id: nil, singleItem: envelopeItem)
    }
} 
