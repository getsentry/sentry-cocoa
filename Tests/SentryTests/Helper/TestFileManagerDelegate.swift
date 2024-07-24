import Foundation
import SentryTestUtils

class TestFileManagerDelegate: NSObject, SentryFileManagerDelegate {
    
    var envelopeItemsDeleted = Invocations<SentryDataCategory>()
    func envelopeItemDeleted(_ envelopeItem: SentryEnvelopeItem, with dataCategory: SentryDataCategory) {
        envelopeItemsDeleted.record(dataCategory)
    }
}
