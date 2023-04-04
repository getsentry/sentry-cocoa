import Foundation
import Sentry

public class TestTimer: Timer {
    public var invalidateCount = 0

    public override func invalidate() {
        // no-op as this timer doesn't actually schedule anything on a runloop
        invalidateCount += 1
    }
}

public class TestSentryNSTimerWrapper: SentryNSTimerWrapper {
    public struct Overrides {
        public var timer: TestTimer!

        var block: ((Timer) -> Void)?

        struct InvocationInfo {
            var target: NSObject
            var selector: Selector
        }
        var invocationInfo: InvocationInfo?
    }

    public var overrides = Overrides()

    public override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = TestTimer()
        overrides.timer = timer
        overrides.block = block
        return timer
    }

    public override func scheduledTimer(withTimeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        let timer = TestTimer()
        overrides.invocationInfo = Overrides.InvocationInfo(target: aTarget as! NSObject, selector: aSelector)
        return timer
    }

    public func fire() {
        if let block = overrides.block {
            block(overrides.timer)
        } else if let invocationInfo = overrides.invocationInfo {
            try! Invocation(target: invocationInfo.target, selector: invocationInfo.selector).invoke()
        }
    }
}
