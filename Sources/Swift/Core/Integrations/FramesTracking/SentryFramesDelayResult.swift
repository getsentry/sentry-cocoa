// swiftlint:disable missing_docs
import Foundation

final class SentryFramesDelayResult {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    let delayDuration: CFTimeInterval
    let framesContributingToDelayCount: UInt
    /// The part of `delayDuration` stemming from the ongoing, not yet recorded frame. This is only
    /// an assumption, because the app may not be rendering at all, e.g. when the screen is off.
    /// The ongoing frame always contributes one frame to `framesContributingToDelayCount`. This is
    /// -1 when the frames delay can't be calculated; check `delayDuration` first.
    let ongoingFrameDelayDuration: CFTimeInterval

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt, ongoingFrameDelayDuration: CFTimeInterval) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
        self.ongoingFrameDelayDuration = ongoingFrameDelayDuration
    }
}

// This class is needed for compatibility with ObjC.
// The pure Swift class also needs to exist since it is used in an internal protocol.
@objc
@_spi(Private) public final class SentryFramesDelayResultSPI: NSObject {
    @objc public let delayDuration: CFTimeInterval
    @objc public let framesContributingToDelayCount: UInt
    @objc public let ongoingFrameDelayDuration: CFTimeInterval

    init(delayDuration: CFTimeInterval, framesContributingToDelayCount: UInt, ongoingFrameDelayDuration: CFTimeInterval) {
        self.delayDuration = delayDuration
        self.framesContributingToDelayCount = framesContributingToDelayCount
        self.ongoingFrameDelayDuration = ongoingFrameDelayDuration
    }
}
// swiftlint:enable missing_docs
