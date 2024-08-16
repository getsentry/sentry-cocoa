import Foundation

@objc
protocol SentryANRTrackerV2Delegate {
    func anrDetected()
    func anrStopped()
}
