import Foundation
@testable import Sentry

class TestEventContextEnricher: SentryEventContextEnricher {
    var enrichWithAppStateInvocations = Invocations<[String: Any]>()
    var enrichWithAppStateReturnValue: [String: Any]?

    func enrichWithAppState(_ context: [String: Any]) -> [String: Any] {
        enrichWithAppStateInvocations.record(context)
        return enrichWithAppStateReturnValue ?? context
    }
}
