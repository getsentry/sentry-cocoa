extension URLSessionTask {
    private enum AssociatedKeys {
        static let trackerSpan = AssociatedObjectAccessor<Span>.Key()
        static let startDate = AssociatedObjectAccessor<Date>.Key()
        static let trackerBreadcrumb = AssociatedObjectAccessor<Bool>.Key()

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        static let networkDetails = AssociatedObjectAccessor<SentryReplayNetworkDetails>.Key()
#endif
    }

    private var trackerSpanAccessor: AssociatedObjectAccessor<Span> {
        .init(on: self, key: AssociatedKeys.trackerSpan)
    }
    var trackerSpan: AssociatedObjectAccessor<Span>.Value? {
        trackerSpanAccessor.value
    }
    func setTrackerSpan(_ newValue: Span?) {
        trackerSpanAccessor.set(newValue)
    }

    private var startDateAccessor: AssociatedObjectAccessor<Date> {
        .init(on: self, key: AssociatedKeys.startDate)
    }
    var startDate: AssociatedObjectAccessor<Date>.Value? {
        startDateAccessor.value
    }
    func setStartDate(_ newValue: Date?) {
        startDateAccessor.set(newValue)
    }

    private var trackerBreadcrumbAccessor: AssociatedObjectAccessor<Bool> {
        .init(
            on: self,
            key: AssociatedKeys.trackerBreadcrumb,
            decode: { ($0 as? NSNumber)?.boolValue },
            encode: { NSNumber(value: $0) }
        )
    }
    var hasBreadcrumb: AssociatedObjectAccessor<Bool>.Value? {
        trackerBreadcrumbAccessor.value
    }
    func setHasBreadcrumb(_ newValue: Bool?) {
        trackerBreadcrumbAccessor.set(newValue)
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private var networkDetailsAccessor: AssociatedObjectAccessor<SentryReplayNetworkDetails> {
        .init(on: self, key: AssociatedKeys.networkDetails)
    }
    var networkDetails: AssociatedObjectAccessor<SentryReplayNetworkDetails>.Value? {
        networkDetailsAccessor.value
    }
    func setNetworkDetails(_ newValue: SentryReplayNetworkDetails?) {
        networkDetailsAccessor.set(newValue)
    }
#endif
}
