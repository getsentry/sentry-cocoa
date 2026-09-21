#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@testable @_spi(Private) import Sentry
#endif

final class TestNSURLRequestBuilder: SentryNSURLRequestBuilder {
    var shouldFailWithError: Bool = false
    var error: NSError?
    let builder = SentryNSURLRequestBuilder()
    
    public override func createEnvelopeRequest(_ envelope: SentryEnvelope, dsn: SentryDsn) throws -> URLRequest {
        let request = try builder.createEnvelopeRequest(envelope, dsn: dsn)
        if shouldFailWithError {
            let error = NSError(domain: "TestErrorDomain", code: 12)
            self.error = error
            throw error
        }
        return request
    }
    
    public override func createEnvelopeRequest(_ envelope: SentryEnvelope, url: URL) throws -> URLRequest {
        let request = try builder.createEnvelopeRequest(envelope, url: url)
        if shouldFailWithError {
            let error = NSError(domain: "TestErrorDomain", code: 12)
            self.error = error
            throw error
        }
        return request
    }
        
}
