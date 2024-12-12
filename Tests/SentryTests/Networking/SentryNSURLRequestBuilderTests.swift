@testable import Sentry
import SentryTestUtils
import XCTest

class SentryNSURLRequestBuilderTests: XCTestCase {
    
    func testCreateEnvelopeRequestWithDsn() throws {
        let sut = getSut()
        
        let envelope = givenEnvelope()
        let dsn = try givenDsn()
        
        let request = try sut.createEnvelopeRequest(envelope, dsn: dsn)
        XCTAssertNotNil(request)
    }
    
    func testCreateEnvelopeRequestWithUrl() throws {
        let sut = getSut()
        
        let envelope = givenEnvelope()
        let url = try givenUrl()
        
        let request = try sut.createEnvelopeRequest(envelope, url: url)
        XCTAssertNotNil(request)
    }
    
    func testCreateEnvelopeRequestWithDsn_failingEnvelopeSerializationThrows() throws {
        let sut = getSut()
        
        let envelopeWithInvalidData = givenEnvelopeWithInvalidData()
        let dsn = try givenDsn()
        
        XCTAssertThrowsError(try sut.createEnvelopeRequest(envelopeWithInvalidData, dsn: dsn))
    }
    
    func testCreateEnvelopeRequestWithUrl_failingEnvelopeSerializationThrows() throws {
        let sut = getSut()
        
        let envelopeWithInvalidData = givenEnvelopeWithInvalidData()
        let url = try givenUrl()
        
        XCTAssertThrowsError(try sut.createEnvelopeRequest(envelopeWithInvalidData, url: url))
    }
    
    // Helper
    
    private func getSut() -> SentryNSURLRequestBuilder {
        return SentryNSURLRequestBuilder()
    }
    
    private func givenDsn() throws -> SentryDsn {
        return try TestConstants.dsn(username: "SentryDataCategoryMapperTests")
    }
                                                    
    private func givenUrl() throws -> URL {
        return try XCTUnwrap(URL(string: "sentry.io/test"))
    }
    
    private func givenEnvelope() -> SentryEnvelope {
        return SentryEnvelope(
            id: SentryId(),
            items: []
        )
    }
    
    private func givenEnvelopeWithInvalidData() -> SentryEnvelope {
        let sdkInfoWithInvalidJSON = SentrySdkInfo(
            name: SentryInvalidJSONString() as String,
            version: "8.0.0",
            integrations: [],
            features: []
        )
        let headerWithInvalidJSON = SentryEnvelopeHeader(
            id: nil,
            sdkInfo: sdkInfoWithInvalidJSON,
            traceContext: nil
        )
        
        return SentryEnvelope(header: headerWithInvalidJSON, items: [])
    }
}
