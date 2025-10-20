import Foundation

@objc @_spi(Private) public protocol SentryDelayedFramesTrackerWrapper {
    func reset()
    func setPreviousFrameSystemTimestamp(_ previousFrameSystemTimestamp: UInt64)
    func getFramesDelay(_ startSystemTimestamp: UInt64, endSystemTimestamp: UInt64, isRunning: Bool, slowFrameThreshold: CFTimeInterval) -> SentryFramesDelayResult
    func recordDelayedFrame(_ startSystemTimestamp: UInt64, thisFrameSystemTimestamp: UInt64, expectedDuration: CFTimeInterval, actualDuration: CFTimeInterval)
}
