// swiftlint:disable missing_docs
import Foundation

/// The  methods are called from a  background thread.
@objc
@_spi(Private) public protocol SentryANRTrackerDelegate {
    func anrDetected(type: SentryANRType)
    
    func anrStopped(result: SentryANRStoppedResult?)
}

@objc @_spi(Private) public final class SentryANRStoppedResult: NSObject {
    
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    
    init(minDuration: TimeInterval, maxDuration: TimeInterval) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
    }
}
// swiftlint:enable missing_docs
