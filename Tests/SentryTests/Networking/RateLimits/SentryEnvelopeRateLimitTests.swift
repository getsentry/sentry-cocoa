#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) import SentryTestUtils
import XCTest

class SentryEnvelopeRateLimitTests: XCTestCase {
    
    private var rateLimits: TestRateLimits!
// swiftlint:disable weak_delegate
// Swiftlint automatically changes this to a weak reference,
// but we need a strong reference to make the test work.
    private var delegate: TestEnvelopeRateLimitDelegate!
// swiftlint:enable weak_delegate
    private var sut: EnvelopeRateLimit?
    
    override func setUp() {
        super.setUp()
        let limits = TestRateLimits()
        rateLimits = limits
        delegate = TestEnvelopeRateLimitDelegate()
        let limiter = EnvelopeRateLimit(rateLimits: limits)
        sut = limiter
        limiter.setDelegate(delegate)
    }
    
    func testNoLimitsActive() throws {
        let envelope = getEnvelope()
        
        let actual = try XCTUnwrap(sut).removeRateLimitedItems(envelope)
        
        XCTAssertEqual(envelope, actual)
    }
    
    func testLimitForErrorActive() throws {
        rateLimits.rateLimits = [SentryDataCategory.error]
        
        let envelope = getEnvelope()
        let actual = try XCTUnwrap(sut).removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypes.session, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
        
        XCTAssertEqual(3, delegate.envelopeItemsDropped.count)
        let expected = [SentryDataCategory.error, SentryDataCategory.error, SentryDataCategory.error]
        XCTAssertEqual(expected, delegate.envelopeItemsDropped.invocations)
    }
    
    func testLimitForSessionActive() throws {
        rateLimits.rateLimits = [SentryDataCategory.session]
        
        let envelope = getEnvelope()
        let actual = try XCTUnwrap(sut).removeRateLimitedItems(envelope)
        
        XCTAssertEqual(3, actual.items.count)
        for item in actual.items {
            XCTAssertEqual(SentryEnvelopeItemTypes.event, item.header.type)
        }
        XCTAssertEqual(envelope.header, actual.header)
        
        XCTAssertEqual(3, delegate.envelopeItemsDropped.count)
        let expected = [SentryDataCategory.session, SentryDataCategory.session, SentryDataCategory.session]
        XCTAssertEqual(expected, delegate.envelopeItemsDropped.invocations)
    }
    
    func testLimitForCustomType() throws {
        rateLimits.rateLimits = [SentryDataCategory.default]
        var envelopeItems = [SentryEnvelopeItem]()
        envelopeItems.append(SentryEnvelopeItem(event: Event()))
        
        let envelopeHeader = SentryEnvelopeItemHeader(type: "customType", length: 10)
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        envelopeItems.append(SentryEnvelopeItem(header: envelopeHeader, data: Data()))
        
        let envelope = SentryEnvelope(id: SentryId(), items: envelopeItems)
        
        let actual = try XCTUnwrap(sut).removeRateLimitedItems(envelope)
        
        XCTAssertEqual(1, actual.items.count)
        XCTAssertEqual(SentryEnvelopeItemTypes.event, try XCTUnwrap(actual.items.first).header.type)
    }
    
    private func getEnvelope() -> SentryEnvelope {
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
