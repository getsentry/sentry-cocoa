#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation

@_spi(Private) public class TestEventContextEnricher: SentryEventContextEnricher {
    public init() {}

    public var enrichWithAppStateInvocations = Invocations<[String: Any]>()
    public var enrichWithAppStateReturnValue: [String: Any]?

    public func enrichWithAppState(_ context: [String: Any]) -> [String: Any] {
        enrichWithAppStateInvocations.record(context)
        return enrichWithAppStateReturnValue ?? context
    }
}
