import Foundation
@_implementationOnly import _SentryPrivate

extension SentryEnvelope {
    
    convenience init?(logs: [SentryLog]) {
        guard !logs.isEmpty else { return nil }
        
        // Create the payload structure expected by Sentry
        let payload = ["items": logs]
        
        do {
            let data = try encodeToJSONData(data: payload)
            
            let header = SentryEnvelopeItemHeader(
                type: "log",
                length: UInt(data.count),
                contentType: "application/vnd.sentry.items.log+json",
                itemCount: NSNumber(value: logs.count)
            )
            let item = SentryEnvelopeItem(header: header, data: data)
            print(item)
            self.init(id: nil, singleItem: item)
        } catch {
            return nil
        }
    }
} 
