import XCTest

class SentryEnvelopeRateLimitTests: XCTestCase {
    
    private var rateLimits : TestRateLimits!
    private var sut: EnvelopeRateLimit!
    
    override func setUp() {
        rateLimits = TestRateLimits()
        sut = EnvelopeRateLimit(rateLimits: rateLimits)
    }
    
    func testNoLimitsActive() {
        let envelope = getEnvelope()
        
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(envelope, actual)
    }
    
    func testLimitForErrorActive() {
        rateLimits.typeLimits = ["error"]
        
        let envelope = getEnvelope()
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypeSession, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
    }
    
    func testLimitForSessionActive() {
        rateLimits.typeLimits = ["session"]
        
        let envelope = getEnvelope()
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypeEvent, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
    }
    
    func testLimitForCustomType() {
        rateLimits.typeLimits = ["default"]
        var envelopeItems = [SentryEnvelopeItem]()
        envelopeItems.append(SentryEnvelopeItem(event: Event()))
        
        let envelopeHeader = SentryEnvelopeItemHeader(type: "customType", length: 10)
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        
        let envelope =  SentryEnvelope(id: "1", items: envelopeItems)
        
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(1, actual.items.count)
        XCTAssertEqual(SentryEnvelopeItemTypeEvent, actual.items[0].header.type)
    }
    
    func getEnvelope() -> SentryEnvelope {
        var envelopeItems = [SentryEnvelopeItem]()
        for _ in Array(0...2) {
            let event = Event()
            envelopeItems.append(SentryEnvelopeItem(event: event))
        }
        
        for _ in Array(0...2) {
            let session = SentrySession()
            envelopeItems.append(SentryEnvelopeItem(session: session))
        }
        
        return SentryEnvelope(id: "1", items: envelopeItems)
    }
    
}
