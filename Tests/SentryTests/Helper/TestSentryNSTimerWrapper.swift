import Foundation
import Sentry

class TestTimer: Timer {
    var invalidateCount = 0

    override func invalidate() {
        // no-op as this timer doesn't actually schedule anything on a runloop
        invalidateCount += 1
    }
}

class TestSentryNSTimerWrapper: SentryNSTimerWrapper {
    struct Overrides {
        var timer: TestTimer!
        var block: ((Timer) -> Void)?
    }

    lazy var overrides = Overrides()

    override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = TestTimer()
        overrides.timer = timer
        overrides.block = block
        return timer
    }

    override func fire() {
        overrides.block?(overrides.timer)
    }
}
