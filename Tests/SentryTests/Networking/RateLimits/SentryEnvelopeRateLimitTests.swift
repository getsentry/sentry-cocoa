import _SentryPrivate
import XCTest

class SentryEnvelopeRateLimitTests: XCTestCase {
    
    private var rateLimits: TestRateLimits!
// swiftlint:disable weak_delegate
// Swiftlint automatically changes this to a weak reference,
// but we need a strong reference to make the test work.
    private var delegate: TestEnvelopeRateLimitDelegate!
// swiftlint:enable weak_delegate
    private var sut: EnvelopeRateLimit!
    
    override func setUp() {
        super.setUp()
        rateLimits = TestRateLimits()
        delegate = TestEnvelopeRateLimitDelegate()
        sut = EnvelopeRateLimit(rateLimits: rateLimits)
        sut.setDelegate(delegate)
    }
    
    func testNoLimitsActive() {
        let envelope = getEnvelope()
        
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(envelope, actual)
    }
    
    func testLimitForErrorActive() {
        rateLimits.rateLimits = [SentryDataCategory.error]
        
        let envelope = getEnvelope()
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypeSession, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
        
        XCTAssertEqual(3, delegate.envelopeItemsDropped.count)
        let expected = [SentryDataCategory.error, SentryDataCategory.error, SentryDataCategory.error]
        XCTAssertEqual(expected, delegate.envelopeItemsDropped.invocations)
    }
    
    func testLimitForSessionActive() {
        rateLimits.rateLimits = [SentryDataCategory.session]
        
        let envelope = getEnvelope()
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypeEvent, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
        
        XCTAssertEqual(3, delegate.envelopeItemsDropped.count)
        let expected = [SentryDataCategory.session, SentryDataCategory.session, SentryDataCategory.session]
        XCTAssertEqual(expected, delegate.envelopeItemsDropped.invocations)
    }
    
    func testLimitForCustomType() {
        rateLimits.rateLimits = [SentryDataCategory.default]
        var envelopeItems = [SentryEnvelopeItem]()
        envelopeItems.append(SentryEnvelopeItem(event: Event()))
        
        let envelopeHeader = SentryEnvelopeItemHeader(type: "customType", length: 10)
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        
        let envelope = SentryEnvelope(id: SentryId(), items: envelopeItems)
        
        let actual = sut.removeRateLimitedItems(envelope)
        
        XCTAssertEqual(1, actual.items.count)
        XCTAssertEqual(SentryEnvelopeItemTypeEvent, actual.items[0].header.type)
    }
    
    func getEnvelope() -> SentryEnvelope {
        var envelopeItems = [SentryEnvelopeItem]()
        for _ in 0...2 {
            let event = Event()
            envelopeItems.append(SentryEnvelopeItem(event: event))
        }
        
        for _ in 0...2 {
            let session = SentrySession(releaseName: "", distinctId: "some-id")
            envelopeItems.append(SentryEnvelopeItem(session: session))
        }
        
        return SentryEnvelope(id: SentryId(), items: envelopeItems)
    }
    
}
