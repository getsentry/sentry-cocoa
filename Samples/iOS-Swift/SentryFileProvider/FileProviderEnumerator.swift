import FileProvider
import Sentry

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor("an anchor".data(using: .utf8)!)
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    func invalidate() {
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        observer.didEnumerate([FileProviderItem(identifier: NSFileProviderItemIdentifier("Any File")),
                               FileProviderItem(identifier: NSFileProviderItemIdentifier("Error Folder")),
                               FileProviderItem(identifier: NSFileProviderItemIdentifier("Transaction Folder"))
                              ])

        if enumeratedItemIdentifier.rawValue == "Transaction Folder" {
            let transaction = SentrySDK.startTransaction(name: "Enumerating itens in folder", operation: "fetching")
            Thread.sleep(forTimeInterval: 5)
            transaction.finish()
        }

        observer.finishEnumerating(upTo: nil)
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(anchor)
    }
}
