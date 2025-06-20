@_spi(Private) @testable import Sentry

private enum Error: Swift.Error {
    case testError
}

final class TestNSURLRequestBuilder: SentryURLRequestBuilder {
    
    var shouldFailWithError: Bool = false
    
    private let requestBuilder = SentryURLRequestBuilder()
    
    override func createEnvelopeRequest(envelope: SentryEnvelope, dsn: SentryDsn) throws -> URLRequest {
        let request = try requestBuilder.createEnvelopeRequest(envelope: envelope, dsn: dsn)
        if self.shouldFailWithError {
            throw Error.testError
        }
        return request
    }
    
    override func createEnvelopeRequest(envelope: SentryEnvelope, url: URL) throws -> URLRequest {
        let request = try requestBuilder.createEnvelopeRequest(envelope: envelope, url: url)
        if self.shouldFailWithError {
            throw Error.testError
        }
        return request
    }
}
