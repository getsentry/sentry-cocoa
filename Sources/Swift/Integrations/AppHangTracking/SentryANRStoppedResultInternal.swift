// swiftlint:disable missing_docs
import Foundation

@objc
public class SentryANRStoppedResultInternal: NSObject {

    @objc public let minDuration: TimeInterval
    @objc public let maxDuration: TimeInterval

    @objc
    public init(minDuration: TimeInterval, maxDuration: TimeInterval) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
    }
}
// swiftlint:enable missing_docs
