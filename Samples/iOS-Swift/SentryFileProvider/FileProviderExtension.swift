import FileProvider
import Sentry

class FileProviderExtension: NSFileProviderExtension {

    override init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.sessionTrackingIntervalMillis = 5_000
            options.profilesSampleRate = 1.0
            options.environment = "test-app"
            options.enableUIViewControllerTracing = false
            options.enableUserInteractionTracing = false
        }

    }

    func invalidate() {
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        return FileProviderItem(identifier: identifier)
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        return nil
    }

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        if containerItemIdentifier.rawValue == "Error Folder" {
            SentrySDK.crash()
        }
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

}
