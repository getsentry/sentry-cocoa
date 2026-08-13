// swiftlint:disable missing_docs
import Foundation

@objc
public enum SentryANRTypeInternal: Int {
    case fatalFullyBlocking
    case fatalNonFullyBlocking
    case fullyBlocking
    case nonFullyBlocking
    case unknown
}

@objc
public protocol SentryANRTrackerInternalDelegate: NSObjectProtocol {
    func anrDetected(_ type: SentryANRTypeInternal)
    func anrStopped(_ result: SentryANRStoppedResultInternal?)
}
// swiftlint:enable missing_docs
