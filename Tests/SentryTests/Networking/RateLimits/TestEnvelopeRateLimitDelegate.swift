#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) import Sentry
#endif
import Foundation
import SentryTestUtils

#if SWIFT_PACKAGE
class TestEnvelopeRateLimitDelegate: SentryTestEnvelopeRateLimitDelegate {
    var envelopeItemsDropped = Invocations<SentryDataCategory>()

    override func envelopeItemDropped(_ item: Any, rawCategory: UInt) {
        guard let category = SentryDataCategory(rawValue: rawCategory) else {
            preconditionFailure("Invalid data category in test bridge")
        }
        envelopeItemsDropped.record(category)
    }
}
#else
class TestEnvelopeRateLimitDelegate: NSObject, SentryEnvelopeRateLimitDelegate {
    var envelopeItemsDropped = Invocations<SentryDataCategory>()

    func envelopeItemDropped(_ envelopeItem: SentryEnvelopeItem, with dataCategory: SentryDataCategory) {
        envelopeItemsDropped.record(dataCategory)
    }
}
#endif
