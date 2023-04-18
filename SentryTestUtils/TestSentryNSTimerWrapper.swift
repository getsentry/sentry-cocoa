import Foundation
import Sentry

// We must not subclass NSTimer, see https://developer.apple.com/documentation/foundation/nstimer#1770465.
// Therefore we return a NSTimer instance here with TimeInterval.infinity.
public class TestSentryNSTimerWrapper: SentryNSTimerWrapper {
    public struct Overrides {
    	private var _timer: Timer?
    
    	public var timer: Timer {
        	get {
         	   _timer ?? Timer()
       		}
            set(newValue) {
                _timer = newValue
            }
    	}

        var block: ((Timer) -> Void)?

        struct InvocationInfo {
            var target: NSObject
            var selector: Selector
        }
        var invocationInfo: InvocationInfo?
    }

    public var overrides = Overrides()

    public override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval.infinity, repeats: repeats, block: block)
        overrides.timer = timer
        overrides.block = block
        return timer
    }

    public override func scheduledTimer(withTimeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        let timer = Timer.scheduledTimer(timeInterval: ti, target: aTarget, selector: aSelector, userInfo: userInfo, repeats: yesOrNo)
        //swiftlint:disable force_cast
        overrides.invocationInfo = Overrides.InvocationInfo(target: aTarget as! NSObject, selector: aSelector)
        //swiftlint:enable force_cast
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
