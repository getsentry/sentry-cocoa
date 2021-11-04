import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestDiplayLinkWrapper: SentryDisplayLinkWrapper {
    
    var target: AnyObject!
    var selector: Selector!
    
    override func link(withTarget target: Any, selector sel: Selector) {
        self.target = target as AnyObject
        self.selector = sel
    }
    
    func call() {
        _ = target.perform(selector)
    }
    
    var internalTimestamp = 0.0
    
    override var timestamp: CFTimeInterval {
        return internalTimestamp
    }
    
    override func invalidate() {
        target = nil
        selector = nil
    }
    
    func givenFrames(_ slow: Int, _ frozen: Int, _ normal: Int) {
        self.call()

        // Slow frames
        for _ in 0..<slow {
            self.internalTimestamp += TestData.slowFrameThreshold + 0.001
            self.call()
        }

        // Frozen frames
        for _ in 0..<frozen {
            self.internalTimestamp += TestData.frozenFrameThreshold + 0.001
            self.call()
        }

        // Normal frames.
        for _ in 0..<(normal - 1) {
            self.internalTimestamp += TestData.slowFrameThreshold - 0.01
            self.call()
        }
    }
}

#endif
