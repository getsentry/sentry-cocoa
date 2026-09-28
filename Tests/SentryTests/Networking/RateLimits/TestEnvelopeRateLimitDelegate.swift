#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import SentryTestsObjCHelpers
#else
@_spi(Private) import Sentry
#endif
import Foundation
import SentryTestUtils

class TestEnvelopeRateLimitDelegate: NSObject, SentryEnvelopeRateLimitDelegate {
    
    var envelopeItemsDropped = Invocations<SentryDataCategory>()
    func envelopeItemDropped(_ envelopeItem: SentryEnvelopeItem, with dataCategory: SentryDataCategory) {
        envelopeItemsDropped.record(dataCategory)
    }
}
