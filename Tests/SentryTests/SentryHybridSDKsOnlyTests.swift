import XCTest

class SentryHybridSDKsOnlyTests: XCTestCase {

    func testStoreEnvelope() {
        let client = TestClient(options: Options())
        SentrySDK.setCurrentHub(TestHub(client: client, andScope: nil))
        
        let envelope = TestConstants.envelope
        SentryHybridSDKsOnly.store(envelope)
        
        XCTAssertEqual(1, client?.storedEnvelopes.count)
        XCTAssertEqual(envelope, client?.storedEnvelopes.first)
    }

    func testEnvelopeWithData() throws {
        let itemData = "{}\n{\"length\":0,\"type\":\"attachment\"}\n".data(using: .utf8)!
        XCTAssertNotNil(SentryHybridSDKsOnly.envelope(with: itemData))
    }
    
    func testGetDebugImages() {
        let sut = SentryHybridSDKsOnly()
        let images = sut.getDebugImages()
        
        // Only make sure we get some images. The actual tests are in
        // SentryDebugImageProviderTests
        XCTAssertGreaterThan(images.count, 100)
    }
}
