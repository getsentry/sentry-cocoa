#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// Applies the scope data the SDK persisted for the previous run to an event of that run.
protocol SentryMXPreviousRunScopeApplying {
    func apply(to event: Event)
}

/// Gives a MetricKit event of the previous run the breadcrumbs and scope data the SDK persisted
/// while that run was active.
///
/// The SDK only keeps the scope data of the run directly before the running process, so this only
/// applies to diagnostics of that run. The data is only persisted where watchdog termination
/// tracking runs; elsewhere the event keeps the metadata of the diagnostic.
final class SentryMXPreviousRunScope: SentryMXPreviousRunScopeApplying {
    private let fileManager: SentryFileManager
    private let scopePersistentStore: SentryScopePersistentStore
    private let maxBreadcrumbs: Int

    init(fileManager: SentryFileManager, scopePersistentStore: SentryScopePersistentStore, maxBreadcrumbs: UInt) {
        self.fileManager = fileManager
        self.scopePersistentStore = scopePersistentStore
        self.maxBreadcrumbs = Int(maxBreadcrumbs)
    }

    func apply(to event: Event) {
        let breadcrumbs = fileManager.readPreviousBreadcrumbs().suffix(maxBreadcrumbs)
        if !breadcrumbs.isEmpty {
            event.serializedBreadcrumbs = Array(breadcrumbs)
        }
        if let user = scopePersistentStore.readPreviousUserFromDisk() {
            event.user = user
        }
        if let environment = scopePersistentStore.readPreviousEnvironmentFromDisk() {
            event.environment = environment
        }
        if let tags = scopePersistentStore.readPreviousTagsFromDisk(), !tags.isEmpty {
            event.tags = tags
        }
        if let extras = scopePersistentStore.readPreviousExtrasFromDisk(), !extras.isEmpty {
            event.extra = extras
        }
        if let fingerprint = scopePersistentStore.readPreviousFingerprintFromDisk(), !fingerprint.isEmpty {
            event.fingerprint = fingerprint
        }
        applyContext(to: event)
    }

    /// Adds the previous run's contexts. The versions the diagnostic was recorded with are more
    /// reliable than the persisted ones, so the event's own context values win.
    private func applyContext(to event: Event) {
        guard let previousContext = scopePersistentStore.readPreviousContextFromDisk(), !previousContext.isEmpty else {
            return
        }
        var context = previousContext
        for (key, eventValues) in event.context ?? [:] {
            context[key] = (previousContext[key] ?? [:]).merging(eventValues) { _, eventValue in eventValue }
        }
        event.context = context
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
