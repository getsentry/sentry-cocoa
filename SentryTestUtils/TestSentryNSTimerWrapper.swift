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
    }

    public lazy var overrides = Overrides()

    public override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = TestTimer()
        overrides.timer = timer
        overrides.block = block
        return timer
    }

    public func fire() {
        overrides.block?(overrides.timer)
    }
}
