import Foundation

@_spi(Private) @objc public final class SentryANRTracker: NSObject {
    
    let helper: SentryANRTrackerProtocol
    
    @objc public init(helper: SentryANRTrackerProtocol) {
        self.helper = helper
    }
    
    @objc(addListener:) public func add(listener: SentryANRTrackerDelegate) {
        helper.addListener(listener)
    }
    
    @objc(removeListener:) public func remove(listener: SentryANRTrackerDelegate) {
        helper.removeListener(listener)
    }
    
    @objc public func clear() {
        helper.clear()
    }
}

@_spi(Private) @objc public protocol SentryANRTrackerProtocol {
    @objc func addListener(_ listender: SentryANRTrackerDelegate)
    @objc func removeListener(_ listener: SentryANRTrackerDelegate)
    
    /// Only used for tests.
    func clear()
}
