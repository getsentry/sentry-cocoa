// swiftlint:disable missing_docs
import Foundation

/// The frames delay of a time period.
enum SentryFramesDelayResult: Equatable {
    /// The frames delay can't be calculated, for example because the frames tracker isn't running
    /// or its record of delayed frames doesn't go back far enough.
    case unavailable
    case delay(duration: CFTimeInterval, framesContributingToDelayCount: UInt)
}

// This class is needed for compatibility with ObjC and for hybrid SDKs, which can't use a Swift
// enum with associated values. The pure Swift type also needs to exist since it is used in an
// internal protocol.
@objc
@_spi(Private) public final class SentryFramesDelayResultSPI: NSObject {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    @objc public let delayDuration: CFTimeInterval
    @objc public let framesContributingToDelayCount: UInt

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
    }

    convenience init(_ result: SentryFramesDelayResult) {
        switch result {
        case .unavailable:
            self.init(delayDuration: -1, framesContributingToDelayCount: 0)
        case let .delay(duration, framesContributingToDelayCount):
            self.init(delayDuration: duration, framesContributingToDelayCount: framesContributingToDelayCount)
        }
    }
}
// swiftlint:enable missing_docs
