#if !SDK_V10
// swiftlint:disable missing_docs
import Foundation

@objc(SentryANRTrackerInternalDelegate)
@_spi(Private) public protocol SentryANRTrackerInternalDelegate: NSObjectProtocol {
    func anrDetected(_ type: SentryANRType)
    func anrStopped(_ result: SentryANRStoppedResultInternal?)
}
// swiftlint:enable missing_docs
#endif // !SDK_V10
