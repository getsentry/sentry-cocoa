import FileProvider
import Sentry
import UniformTypeIdentifiers

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }

    func invalidate() {
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        // Start transaction for enumeration
        let transaction = SentrySDK.startTransaction(
            name: "file-provider-enumerate-items",
            operation: "file.enumerate.items"
        )
        
        // Mock file enumeration
        var items: [NSFileProviderItem] = []
        
        if enumeratedItemIdentifier == .rootContainer {
            // Root container - provide sample files
            items = [
                FileProviderItem(
                    identifier: NSFileProviderItemIdentifier("sentry-logs"),
                    filename: "sentry-debug.log",
                    typeIdentifier: UTType.plainText.identifier,
                    documentSize: 1_024
                ),
                FileProviderItem(
                    identifier: NSFileProviderItemIdentifier("sentry-config"),
                    filename: "sentry-config.json",
                    typeIdentifier: UTType.json.identifier,
                    documentSize: 512
                )
            ]
            
            transaction.setData(value: items.count, key: "items_count")
            transaction.setData(value: "root", key: "container_type")
        } else {
            // Sub-containers would have their own items
            transaction.setData(value: 0, key: "items_count")
            transaction.setData(value: "sub", key: "container_type")
        }
        
        // Simulate enumeration delay and potential errors
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) {
            // Check for simulated error
            if self.enumeratedItemIdentifier.rawValue.contains("error") {
                let error = NSFileProviderError(.serverUnreachable)
                observer.finishEnumeratingWithError(error)
                return
            }
            
            // Provide the items to the observer
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil) // No more pages
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        // Start transaction for change enumeration
        let transaction = SentrySDK.startTransaction(
            name: "file-provider-enumerate-changes",
            operation: "file.enumerate.changes"
        )

        // For this demo, we'll simulate no changes
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) {
            let currentAnchor = NSFileProviderSyncAnchor(Date().timeIntervalSince1970.description.data(using: .utf8)!)
            observer.finishEnumeratingChanges(upTo: currentAnchor, moreComing: false)
        }
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = NSFileProviderSyncAnchor(Date().timeIntervalSince1970.description.data(using: .utf8)!)
        
        completionHandler(anchor)
    }
} 
