import Foundation

/// The  methods are called from a  background thread.
@objc
protocol SentryANRTrackerDelegate {
    func anrDetected(type: SentryANRType)
    func anrStopped()
}

@objc
enum SentryANRType: Int {
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}
