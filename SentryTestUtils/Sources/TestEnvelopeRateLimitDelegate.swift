#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC
import XCTest

@_spi(Private)
public final class TestEnvelopeRateLimitDelegate: SentryTestEnvelopeRateLimitDelegateWrapper {
    public let envelopeItemsDropped = Invocations<SentryDataCategory>()
    public let droppedItems = Invocations<SentryEnvelopeItem>()

    public override func wrapper_envelopeItemDropped(_ envelopeItem: Any, withCategory category: UInt) {
        guard let item = envelopeItem as? SentryEnvelopeItem,
              let category = SentryDataCategory(rawValue: category) else {
            XCTFail("Rate-limit delegate received an invalid envelope item or category")
            return
        }
        droppedItems.record(item)
        envelopeItemsDropped.record(category)
    }
}
