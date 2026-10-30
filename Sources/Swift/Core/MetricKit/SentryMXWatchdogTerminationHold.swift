#if (os(iOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import Foundation
import UIKit

/// Holds the watchdog termination event of the previous run until MetricKit explains the
/// termination.
///
/// MetricKit delivers its diagnostics after the SDK detected the watchdog termination at launch.
/// The event is stored to disk with the terminated run, so it survives a quick relaunch. It is sent
/// unchanged when the hold ends, when the app moves to the background, or on the next launch,
/// unless a matching diagnostic took it before. See decision 41 in `develop-docs/DECISIONS.md`.
final class SentryMXWatchdogTerminationHold: SentryMXWatchdogTerminationHolding, SentryWatchdogTerminationEventHold {
    /// How long the event waits for MetricKit after launch.
    static let duration: TimeInterval = 30

    private struct Pending: Codable {
        let run: SentryMXFatalRun
        /// The serialized event.
        let event: Data
    }

    private let path: String
    private let runStore: SentryMXRunStore
    private let isEnabled: Bool
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let captureFatalEvent: (Event) -> Void
    private let lock = NSLock()
    private var backgroundObserver: NSObjectProtocol?

    /// - Parameter isEnabled: Whether the hold applies. When disabled, the hold only sends events
    ///   left over from an earlier launch.
    init(
        path: String,
        runStore: SentryMXRunStore,
        isEnabled: Bool,
        dispatchQueue: SentryDispatchQueueWrapper,
        notificationCenter: SentryNSNotificationCenterWrapper,
        captureFatalEvent: @escaping (Event) -> Void = { SentrySDKInternal.captureFatalEvent($0) }
    ) {
        self.path = path
        self.runStore = runStore
        self.isEnabled = isEnabled
        self.dispatchQueue = dispatchQueue
        self.notificationCenter = notificationCenter
        self.captureFatalEvent = captureFatalEvent
    }

    deinit {
        if let backgroundObserver {
            notificationCenter.removeObserver(backgroundObserver, name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
    }

    /// Whether the hold applies to the options. MetricKit only reports which process recorded a
    /// diagnostic on iOS 17 and visionOS, and only delivers diagnostics while they are enabled.
    static func isEnabled(for options: Options) -> Bool {
        guard options.experimental.metrickit.enrichWatchdogTerminations,
              !SentryMetricKit.enabledDiagnostics(for: options).isEmpty else {
            return false
        }
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }

    // MARK: - Holding

    /// Holds the watchdog termination event of the previous run.
    ///
    /// - Returns: `false` when the event can't be held, so the caller sends it right away.
    func hold(_ event: Event) -> Bool {
        guard isEnabled else {
            return false
        }
        guard let previousRun = runStore.previousRun,
              let run = runStore.fatalRuns.first(where: { $0.runId == previousRun.runId && $0.report == .watchdogTermination }) else {
            SentrySDKLog.debug("The watchdog terminated run isn't recorded, sending the watchdog termination right away")
            return false
        }
        guard let eventData = SentrySerializationSwift.data(withJSONObject: event.serialize()) else {
            SentrySDKLog.warning("Failed to serialize the watchdog termination event, sending it right away")
            return false
        }

        let stored = lock.synchronized {
            write(Pending(run: run, event: eventData))
        }
        guard stored else {
            return false
        }

        SentrySDKLog.debug("Holding the watchdog termination of run \(run.runId) for MetricKit")
        backgroundObserver = notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.sendPendingEvent()
        }
        dispatchQueue.dispatch(after: Self.duration) { [weak self] in
            self?.sendPendingEvent()
        }
        return true
    }

    /// Sends the held event unchanged, including an event left over from an earlier launch.
    func sendPendingEvent() {
        guard let event = lock.synchronized({ takePending()?.event }) else {
            return
        }
        SentrySDKLog.debug("MetricKit didn't explain the watchdog termination, sending it unchanged")
        captureFatalEvent(event)
    }

    // MARK: - SentryMXWatchdogTerminationHolding

    func takeEvent(matching diagnostic: SentryMXDiagnosticRun) -> Event? {
        lock.synchronized {
            guard let pending = read(), case .run = SentryMXRunMatcher.match(diagnostic, in: [pending.run]) else {
                return nil
            }
            return takePending()?.event
        }
    }

    func send(_ event: Event) {
        captureFatalEvent(event)
    }

    // MARK: - File

    /// Removes the pending event from disk and returns it together with its run.
    private func takePending() -> (run: SentryMXFatalRun, event: Event)? {
        guard let pending = read() else {
            return nil
        }
        removeFile()
        // The run is handled, so a later diagnostic doesn't match it again.
        runStore.remove(pending.run)
        guard let event = SentryEventDecoder.decodeEvent(jsonData: pending.event) else {
            SentrySDKLog.warning("Failed to decode the held watchdog termination event")
            return nil
        }
        return (pending.run, event)
    }

    private func read() -> Pending? {
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Pending.self, from: data)
        } catch {
            SentrySDKLog.warning("Failed to decode the held watchdog termination, removing it: \(error)")
            removeFile()
            return nil
        }
    }

    private func write(_ pending: Pending) -> Bool {
        do {
            try JSONEncoder().encode(pending).write(to: URL(fileURLWithPath: path), options: .atomic)
            return true
        } catch {
            SentrySDKLog.warning("Failed to store the held watchdog termination: \(error)")
            return false
        }
    }

    private func removeFile() {
        try? FileManager.default.removeItem(atPath: path)
    }
}

#endif // (os(iOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
