#if !SDK_V10
// swiftlint:disable missing_docs
import Foundation

@objc(SentryANRStoppedResultInternal)
@_spi(Private) public final class SentryANRStoppedResultInternal: NSObject {
    @objc public let minDuration: TimeInterval
    @objc public let maxDuration: TimeInterval

    @objc public init(minDuration: TimeInterval, maxDuration: TimeInterval) {
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        super.init()
    }
}
// swiftlint:enable missing_docs
#endif // !SDK_V10
