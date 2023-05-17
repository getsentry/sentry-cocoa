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
    }

    public override func cancel() {
        // no-op
    }

    public func fire() {
        self.overrides.eventHandler?()
    }
}
