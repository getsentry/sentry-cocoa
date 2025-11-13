import Foundation

final class SentryFramesDelayResult {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    let delayDuration: CFTimeInterval
    let framesContributingToDelayCount: UInt

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
    }
}

// This class is needed for compatibility with ObjC.
// The pure Swift class also needs to exist since it is used in an internal protocol.
@objc
@_spi(Private) public final class SentryFramesDelayResultSPI: NSObject {
    @objc public let delayDuration: CFTimeInterval
    @objc public let framesContributingToDelayCount: UInt

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
    }
}
