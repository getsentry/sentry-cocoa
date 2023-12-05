import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

public enum GPUFrame {
    case normal
    case slow
    case frozen
}

public enum FrameRate: UInt64 {
    case low  = 60
    case high = 120

    public var tickDuration: CFTimeInterval {
        return 1 / CFTimeInterval(self.rawValue)
    }
}

public class TestDisplayLinkWrapper: SentryDisplayLinkWrapper {
    public var target: AnyObject!
    public var selector: Selector!
    public var currentFrameRate: FrameRate = .low
    let frozenFrameThreshold = 0.7
    public let slowestSlowFrameDuration: Double
    public let fastestFrozenFrameDuration: Double
    
    public var dateProvider: TestCurrentDateProvider
    /// The smallest magnitude of time that is significant to how frames are classified as normal/slow/frozen.
    public let timeEpsilon = 0.001

    public init(dateProvider: TestCurrentDateProvider = TestCurrentDateProvider()) {
        self.dateProvider = dateProvider
        // The test date provider converts the duration from UInt64 to a double back and forth.
        // Therefore we have rounding issues, and subtract or add the timeEpsilon.
        slowestSlowFrameDuration = frozenFrameThreshold - timeEpsilon
        fastestFrozenFrameDuration = frozenFrameThreshold + timeEpsilon
    }

    public var linkInvocations = Invocations<Void>()
    public override func link(withTarget target: Any, selector sel: Selector) {
        linkInvocations.record(Void())
        self.target = target as AnyObject
        self.selector = sel
    }

    public override var timestamp: CFTimeInterval {
        return dateProvider.systemTime().toTimeInterval()
    }

    public override var targetTimestamp: CFTimeInterval {
        return dateProvider.systemTime().toTimeInterval() + currentFrameRate.tickDuration
    }

    public var invalidateInvocations = Invocations<Void>()
    public override func invalidate() {
        target = nil
        selector = nil
        invalidateInvocations.record(Void())
    }
    
    public func call() {
        _ = target.perform(selector)
    }

    public func changeFrameRate(_ newFrameRate: FrameRate) {
        currentFrameRate = newFrameRate
    }
    
    public func normalFrame() {
        dateProvider.advance(by: currentFrameRate.tickDuration)
        call()
    }
    
    public func fastestSlowFrame() -> CFTimeInterval {
        let duration: Double = slowFrameThreshold(currentFrameRate.rawValue) + timeEpsilon
        dateProvider.advance(by: duration)
        call()
        return duration
    }

    public func middlingSlowFrame() -> CFTimeInterval {
        let duration: Double = (frozenFrameThreshold - (slowFrameThreshold(currentFrameRate.rawValue) + timeEpsilon)) / 2.0
        dateProvider.advance(by: duration)
        call()
        return duration
    }
    
    public func slowestSlowFrame() -> CFTimeInterval {
        dateProvider.advance(by: slowestSlowFrameDuration)
        call()
        return slowestSlowFrameDuration
    }

    public func fastestFrozenFrame() -> CFTimeInterval {
        dateProvider.advance(by: fastestFrozenFrameDuration)
        call()
        return fastestFrozenFrameDuration
    }

    /// There's no upper bound for a frozen frame, except maybe for the watchdog time limit.
    /// - parameter extraTime: the additional time to add to the frozen frame threshold when simulating a frozen frame.
    public func slowerFrozenFrame(extraTime: TimeInterval = 0.1) {
        dateProvider.advance(by: frozenFrameThreshold + extraTime)
        call()
    }
    
    public func renderFrames(_ slow: Int, _ frozen: Int, _ normal: Int) {
        self.call()

        for _ in 0..<slow {
            _ = fastestSlowFrame()
        }
        
        for _ in 0..<frozen {
            _ = fastestFrozenFrame()
        }

        for _ in 0..<(normal - 1) {
            normalFrame()
        }
    }
}

#endif
