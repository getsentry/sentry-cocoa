@_implementationOnly import _SentryPrivate

private enum Error: Swift.Error {
    case serializationError
}

@objc(SentryNSURLRequestBuilder)
@_spi(Private) public class SentryURLRequestBuilder: NSObject {
    
    @objc
    public func createEnvelopeRequest(envelope: SentryEnvelope, dsn: SentryDsn) throws -> URLRequest {
        guard let data = SentrySerialization.data(with: envelope) else {
            SentryLog.error("Envelope cannot be converted to data")
            throw Error.serializationError
        }
        return try SentryURLRequestFactory.envelopeRequest(with: dsn, data: data)
    }
    
    @objc
    public func createEnvelopeRequest(envelope: SentryEnvelope, url: URL) throws -> URLRequest {
        guard let data = SentrySerialization.data(with: envelope) else {
            SentryLog.error("Envelope cannot be converted to data")
            throw Error.serializationError
        }
        return try SentryURLRequestFactory.envelopeRequest(with: url, data: data, authHeader: nil)
    }
}
