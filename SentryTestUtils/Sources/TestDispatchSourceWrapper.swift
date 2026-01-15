// swiftlint:disable missing_docs
import Foundation
@_spi(Private) @testable import Sentry

@_spi(Private) public class TestDispatchSourceWrapper: SentryDispatchSourceWrapper {
    public struct Override {
        public var eventHandler: (() -> Void)?
    }
    public var overrides = Override()

    public init(eventHandler: @escaping () -> Void) {
        self.overrides.eventHandler = eventHandler
        // Create a timer that never fires on its own, so we can control when it fires via `fire()`.
        super.init(interval: Int.max, leeway: 1_000, queue: SentryDispatchQueueWrapper(), eventHandler: {})
        eventHandler() // SentryDispatchSourceWrapper constructs a timer so that it fires with no initial delay
    }

    public override func cancel() {
        // no-op
    }

    public func fire() {
        self.overrides.eventHandler?()
    }
}
// swiftlint:enable missing_docs
