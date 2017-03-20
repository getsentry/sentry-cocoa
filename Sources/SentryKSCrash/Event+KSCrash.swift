import Sentry

extension Event {
	/// This will set threads and debugMeta if not nil with snapshot of stacktrace if called
	/// SentryClient.shared?.snapshotStacktrace()
	@objc public func fetchStacktrace() {
		if threads == nil {
			threads = SentryClient.shared?.stacktraceSnapshot?.threads
		}
		if debugMeta == nil {
			debugMeta = SentryClient.shared?.stacktraceSnapshot?.debugMeta
		}
	}
}
