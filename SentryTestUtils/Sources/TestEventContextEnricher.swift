import Foundation
@testable import Sentry

class TestEventContextEnricher: SentryEventContextEnricher {
    var enrichEventContextInvocations = Invocations<[String: Any]>()
    var enrichEventContextReturnValue: [String: Any]?

    func enrichEventContext(_ context: [String: Any]) -> [String: Any] {
        enrichEventContextInvocations.record(context)
        return enrichEventContextReturnValue ?? context
    }
}
