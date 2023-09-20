import Foundation
import Sentry

public class TestDispatchSourceWrapper: SentryDispatchSourceWrapper {
    public struct Override {
        public var eventHandler: (() -> Void)?
    }
    public var overrides = Override()

    public init(eventHandler: @escaping () -> Void) {
        self.overrides.eventHandler = eventHandler
        super.init()
        eventHandler() // SentryDispatchSourceWrapper constructs a timer so that it fires with no initial delay
    }

    public override func cancel() {
        // no-op
    }

    public func fire() {
        self.overrides.eventHandler?()
    }
}
