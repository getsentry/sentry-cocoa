import Foundation
@_spi(Private) @testable import Sentry

// We must not subclass NSTimer, see https://developer.apple.com/documentation/foundation/nstimer#1770465.
// Therefore we return a NSTimer instance here with TimeInterval.infinity.
public class TestSentryNSTimerFactory: SentryNSTimerFactory {
    public struct Overrides {
        private var _interval: TimeInterval?
        
        public var timer: Timer
        var block: ((Timer) -> Void)?
        
        var interval: TimeInterval {
            get {
                _interval ?? TimeInterval.infinity
            }
            set {
                _interval = newValue
            }
        }
        
        var lastFireDate: Date
        
        struct InvocationInfo {
            var target: NSObject
            var selector: Selector
        }
        var invocationInfo: InvocationInfo?
        
        init(timer: Timer, interval: TimeInterval? = nil, block: ((Timer) -> Void)? = nil, lastFireDate: Date, invocationInfo: InvocationInfo? = nil) {
            self.timer = timer
            self._interval = interval
            self.block = block
            self.lastFireDate = lastFireDate
            self.invocationInfo = invocationInfo
        }
    }
    
    public var overrides: Overrides?
    
    private var currentDateProvider: SentryCurrentDateProvider
    
    @_spi(Private) public init(currentDateProvider: SentryCurrentDateProvider) {
        self.currentDateProvider = currentDateProvider
        super.init()
    }
}

// MARK: Superclass overrides
public extension TestSentryNSTimerFactory {
    override func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval.infinity, repeats: repeats, block: block)
        overrides = Overrides(timer: timer, interval: interval, block: block, lastFireDate: currentDateProvider.date())
        return timer
    }
    
    override func scheduledTimer(withTimeInterval ti: TimeInterval, target aTarget: Any, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        let timer = Timer.scheduledTimer(timeInterval: ti, target: aTarget, selector: aSelector, userInfo: userInfo, repeats: yesOrNo)
        //swiftlint:disable force_cast
        let invocationInfo = Overrides.InvocationInfo(target: aTarget as! NSObject, selector: aSelector)
        //swiftlint:enable force_cast
        overrides = Overrides(timer: timer, interval: ti, lastFireDate: currentDateProvider.date(), invocationInfo: invocationInfo)
        return timer
    }
}

// MARK: Extensions
public extension TestSentryNSTimerFactory {
    enum TestTimerError: Error {
        case timerNotInitialized
    }
    
    // check the current time against the last fire time and interval, and if enough time has elapsed, execute any block/invocation registered with the timer
    func check() throws {
        guard let overrides = overrides else { throw TestTimerError.timerNotInitialized }
        let currentDate = currentDateProvider.date()
        if currentDate.timeIntervalSince(overrides.lastFireDate) >= overrides.interval {
            try fire()
        }
    }

    // immediately execute any block/invocation registered with the timer
    func fire() throws {
        guard var overrides = overrides else { throw TestTimerError.timerNotInitialized }
        overrides.lastFireDate = currentDateProvider.date()
        if let block = overrides.block {
            block(overrides.timer)
        } else if let invocationInfo = overrides.invocationInfo {
            try Invocation(target: invocationInfo.target, selector: invocationInfo.selector).invoke()
        }
    }
    
    func isTimerInitialized() -> Bool {
        return overrides != nil
    }
    
    func reset() {
        overrides = nil
    }
}
