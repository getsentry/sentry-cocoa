import Foundation

class TestFileManagerDelegate: NSObject, SentryFileManagerDelegate {
    
    var envelopeItemsDeleted = Invocations<SentryDataCategory>()
    func envelopeItemDeleted(_ dataCategory: SentryDataCategory) {
        envelopeItemsDeleted.record(dataCategory)
    }
}
