import ContactProvider
import Contacts
import Foundation

/// Enumerates one contact per SDK status check, so the result is visible in the Contacts app.
final class ContactProviderRootContainerEnumerator: ContactItemEnumerator {
    private static let generationMarker = Data("iOS-Swift-ContactProviderExtension".utf8)

    func enumerateContent(in page: ContactItemPage, for observer: ContactItemContentObserver) async {
        // All items fit into the first page
        if page == .initialPage {
            observer.didEnumerate(statusItems())
        }
        observer.didFinishEnumeratingContent(upTo: Self.generationMarker)
    }

    func enumerateChanges(startingAt syncAnchor: ContactItemSyncAnchor, for observer: ContactItemChangeObserver) async {
        // The status is only known at runtime, so every sync reports all items as updated
        observer.didUpdate(statusItems())
        observer.didFinishEnumeratingChanges(
            upTo: ContactItemSyncAnchor(generationMarker: Self.generationMarker, offset: 0),
            moreComing: false
        )
    }

    func invalidate() async {
        // Nothing to clean up
    }

    private func statusItems() -> [ContactItem] {
        return [
            statusItem(identifier: "sentry-enabled", title: "Sentry Enabled", passed: ContactProviderExtension.isSentryEnabled),
            statusItem(identifier: "anr-not-installed", title: "ANR Not Installed", passed: !ContactProviderExtension.isANRInstalled),
            statusItem(identifier: "watchdog-not-installed", title: "Watchdog Not Installed", passed: !ContactProviderExtension.isWatchdogInstalled)
        ]
    }

    private func statusItem(identifier: String, title: String, passed: Bool) -> ContactItem {
        let contact = CNMutableContact()
        contact.givenName = "\(title): \(passed ? "✅" : "❌")"
        contact.organizationName = "Sentry Contact Provider"
        return .contact(contact, ContactItem.Identifier(identifier))
    }
}
