import Foundation
import SentryTestUtils

class TestEnvelopeRateLimitDelegate: NSObject, SentryEnvelopeRateLimitDelegate {
    
    var envelopeItemsDropped = Invocations<SentryDataCategory>()
    func envelopeItemDropped(_ dataCategory: SentryDataCategory) {
        envelopeItemsDropped.record(dataCategory)
    }
}
