final class URLSessionTaskNetworkTrackerState {
    struct SpanCompletion {
        let status: SentrySpanStatus
        let responseStatusCode: Int?
    }

    enum SpanState {
        case idle
        case creating
        case active(Span)
        case completionPending(SpanCompletion)
        case completed
    }

    struct Values {
        var spanState = SpanState.idle
        var startDate: Date?
        var hasBreadcrumb = false

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        var networkDetails: SentryReplayNetworkDetails?
#endif
    }

    let values = SentryMutex(Values())
}

extension URLSessionTask {
    private enum AssociatedKeys {
        static let networkTrackerState = AssociatedObjectAccessor<URLSessionTaskNetworkTrackerState>.Key()
        static let stateCreation = SentryMutex<Void>(())
    }

    private var networkTrackerStateAccessor: AssociatedObjectAccessor<URLSessionTaskNetworkTrackerState> {
        .init(on: self, key: AssociatedKeys.networkTrackerState)
    }

    private var existingNetworkTrackerState: URLSessionTaskNetworkTrackerState? {
        guard case .valid(let state) = networkTrackerStateAccessor.value else {
            return nil
        }
        return state
    }

    func withNetworkTrackerState<Result>(
        _ body: (inout URLSessionTaskNetworkTrackerState.Values) throws -> Result
    ) rethrows -> Result {
        let state = existingNetworkTrackerState ?? AssociatedKeys.stateCreation.withLock { _ in
            if let state = existingNetworkTrackerState {
                return state
            }

            let state = URLSessionTaskNetworkTrackerState()
            networkTrackerStateAccessor.set(state)
            return state
        }
        return try state.values.withLock(body)
    }

    func withNetworkTrackerStateIfAvailable<Result>(
        _ body: (inout URLSessionTaskNetworkTrackerState.Values) throws -> Result
    ) rethrows -> Result? {
        try existingNetworkTrackerState.flatMap { try $0.values.withLockIfAvailable(body) }
    }

    var trackerSpan: Span? {
        withNetworkTrackerState {
            guard case .active(let span) = $0.spanState else {
                return nil
            }
            return span
        }
    }

    var startDate: Date? {
        withNetworkTrackerState { $0.startDate }
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    var networkDetails: SentryReplayNetworkDetails? {
        withNetworkTrackerState { $0.networkDetails }
    }
#endif
}
