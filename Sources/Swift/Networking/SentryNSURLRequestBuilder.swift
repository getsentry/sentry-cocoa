@_spi(Private) @objc public class SentryNSURLRequestBuilder: NSObject {
    
    enum Error: Swift.Error {
        case serializeError
    }
    
    @objc public func createEnvelopeRequest(_ envelope: SentryEnvelope, dsn: SentryDsn) throws -> URLRequest {
        let data = SentrySerializationSwift.data(with: envelope)
        guard let data else {
            SentrySDKLog.error("Envelope cannot be converted to data")
            throw Error.serializeError
        }
        return try SentryURLRequestFactory.envelopeRequest(with: dsn, data: data)
    }
    
    @objc public func createEnvelopeRequest(_ envelope: SentryEnvelope, url: URL) throws -> URLRequest {
        let data = SentrySerializationSwift.data(with: envelope)
        guard let data else {
            SentrySDKLog.error("Envelope cannot be converted to data")
            throw Error.serializeError
        }
        return try SentryURLRequestFactory.envelopeRequest(with: url, data: data, authHeader: nil)
        
    }
}
