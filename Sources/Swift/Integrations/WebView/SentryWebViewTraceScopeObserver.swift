#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate

/// Refreshes the tracked WebViews when the scope's span or propagation context changes.
///
/// The scope calls observers synchronously from any thread while holding its locks, so the refresh
/// is dispatched to the main actor, and changes that arrive before it runs are coalesced into one.
final class SentryWebViewTraceScopeObserver: NSObject, SentryScopeObserver {
    private weak var refresher: SentryWebViewTraceRefresher?
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let isRefreshScheduled = SentryMutex(false)

    init(
        refresher: SentryWebViewTraceRefresher,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.refresher = refresher
        self.scheduleOnMain = scheduleOnMain
    }

    func setTraceContext(_ traceContext: [String: Any]?) {
        scheduleRefresh()
    }

    func clear() {
        scheduleRefresh()
    }

    func setUser(_ user: User?) {}
    func setTags(_ tags: [String: String]?) {}
    func setExtras(_ extras: [String: Any]?) {}
    func setContext(_ context: [String: [String: Any]]?) {}
    func setDist(_ dist: String?) {}
    func setEnvironment(_ environment: String?) {}
    func setFingerprint(_ fingerprint: [String]?) {}
    func setLevel(_ level: SentryLevel) {}
    func setAttributes(_ attributes: [String: Any]?) {}
    func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {}
    func clearBreadcrumbs() {}

    private func scheduleRefresh() {
        let shouldSchedule = isRefreshScheduled.withLock { isScheduled -> Bool in
            guard !isScheduled else {
                return false
            }
            isScheduled = true
            return true
        }
        guard shouldSchedule else {
            return
        }

        scheduleOnMain { [weak self] in
            guard let self = self else {
                return
            }
            self.isRefreshScheduled.withLock { $0 = false }
            MainActor.assumeIsolated {
                self.refresher?.refreshAll()
            }
        }
    }
}
#endif
