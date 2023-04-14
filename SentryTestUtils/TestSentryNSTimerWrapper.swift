import Foundation
import Sentry

// We must not subclass NSTimer, see https://developer.apple.com/documentation/foundation/nstimer#1770465.
// Therefore we return a NSTimer instance here with TimeInterval.infinity.
public class TestSentryNSTimerWrapper: SentryNSTimerWrapper {

    private var _timer: Timer?
    
    public var timer: Timer {
        get {
            _timer!
        }
    }

    public override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        _timer = Timer.scheduledTimer(withTimeInterval: TimeInterval.infinity, repeats: repeats, block: block)
        
        return _timer!
    }

    public func fire() {
        _timer?.fire()
    }
}
