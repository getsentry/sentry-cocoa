import Foundation

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestDisplayLinkWrapper: SentryDisplayLinkWrapper {
    
    var target: AnyObject!
    var selector: Selector!
    var internalTimestamp = 0.0
    var internalActualFrameRate = 60.0
    let frozenFrameThreshold = 0.7
    
    var frameDuration: Double {
        return 1.0 / internalActualFrameRate
    }
    
    private var slowFrameThreshold: CFTimeInterval {
        return 1 / (Double(internalActualFrameRate) - 1.0)
    }
    
    override func link(withTarget target: Any, selector sel: Selector) {
        self.target = target as AnyObject
        self.selector = sel
    }
    
    func call() {
        _ = target.perform(selector)
    }

    override var timestamp: CFTimeInterval {
        return internalTimestamp
    }

    func changeFrameRate(_ newFrameRate: Double) {
        internalActualFrameRate = newFrameRate
    }
    
    func normalFrame() {
        internalTimestamp += frameDuration
        call()
    }
    
    func slowFrame() {
        internalTimestamp += slowFrameThreshold + 0.001
        call()
    }
    
    func almostFrozenFrame() {
        internalTimestamp += frozenFrameThreshold
        call()
    }
    
    func frozenFrame() {
        internalTimestamp += frozenFrameThreshold + 0.001
        call()
    }
    
    override var targetTimestamp: CFTimeInterval {
        return internalTimestamp + frameDuration
    }
    
    override func invalidate() {
        target = nil
        selector = nil
    }
    
    func givenFrames(_ slow: Int, _ frozen: Int, _ normal: Int) {
        self.call()

        for _ in 0..<slow {
            slowFrame()
        }
        
        for _ in 0..<frozen {
            frozenFrame()
        }

        for _ in 0..<(normal - 1) {
            normalFrame()
        }
    }
}

#endif
