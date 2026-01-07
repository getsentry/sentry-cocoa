import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS))

#if os(iOS)
/// An array of dictionaries that each contain a start and end timestamp for a rendered frame.
@_spi(Private) public typealias SentryFrameInfoTimeSeries = [[String: NSNumber]]
#endif // os(iOS)

/// Represents screen frame metrics including total, slow, and frozen frames.
///
/// - Warning: This feature is not available in `DebugWithoutUIKit` and `ReleaseWithoutUIKit`
/// configurations even when targeting iOS or tvOS platforms.
@objc @_spi(Private)
public final class SentryScreenFrames: NSObject, NSCopying {
    
    // MARK: - Properties
    
    /// Total number of frames rendered
    @objc
    public let total: UInt
    
    /// Number of frames that were frozen (took longer than 700ms to render)
    @objc
    public let frozen: UInt
    
    /// Number of frames that were slow (took longer than 16.67ms but less than 700ms to render)
    @objc
    public let slow: UInt
    
#if os(iOS)
    /// Array of dictionaries describing slow frames' timestamps.
    /// Each dictionary has a start and end timestamp for every such frame,
    /// keyed under `start_timestamp` and `end_timestamp`.
    @objc
    public let slowFrameTimestamps: SentryFrameInfoTimeSeries
    
    /// Array of dictionaries describing frozen frames' timestamps.
    /// Each dictionary has a start and end timestamp for every such frame,
    /// keyed under `start_timestamp` and `end_timestamp`.
    @objc
    public let frozenFrameTimestamps: SentryFrameInfoTimeSeries
    
    /// Array of dictionaries describing the screen refresh rate at all points in time that it changes.
    /// This can happen when modern devices go into low power mode, for example.
    /// Each dictionary contains keys `timestamp` and `frame_rate`.
    @objc
    public let frameRateTimestamps: SentryFrameInfoTimeSeries
#endif // os(iOS)
    
    // MARK: - Initialization
    
    /// Creates a `SentryScreenFrames` instance with basic frame metrics.
    /// - Parameters:
    ///   - total: Total number of frames rendered
    ///   - frozen: Number of frozen frames
    ///   - slow: Number of slow frames
    @objc public init(total: UInt, frozen: UInt, slow: UInt) {
#if SENTRY_NO_UIKIT
        let warningText = "SentryScreenFrames only works with UIKit enabled. Ensure you're using the right configuration of Sentry that links UIKit."
        SentrySDKLog.warning(warningText)
        assertionFailure(warningText)
#endif // SENTRY_NO_UIKIT
        
    #if os(iOS)
        self.total = total
        self.frozen = frozen
        self.slow = slow
        self.slowFrameTimestamps = []
        self.frozenFrameTimestamps = []
        self.frameRateTimestamps = []
    #else
        self.total = total
        self.frozen = frozen
        self.slow = slow
    #endif // !(os(watchOS) || os(tvOS) || os(visionOS))

        super.init()
    }
    
#if os(iOS)
    /// Creates a `SentryScreenFrames` instance with detailed frame metrics including timing data.
    /// - Parameters:
    ///   - total: Total number of frames rendered
    ///   - frozen: Number of frozen frames
    ///   - slow: Number of slow frames
    ///   - slowFrameTimestamps: Array of dictionaries with slow frame timing data
    ///   - frozenFrameTimestamps: Array of dictionaries with frozen frame timing data
    ///   - frameRateTimestamps: Array of dictionaries with frame rate change data
    @objc public init(
        total: UInt,
        frozen: UInt,
        slow: UInt,
        slowFrameTimestamps: SentryFrameInfoTimeSeries,
        frozenFrameTimestamps: SentryFrameInfoTimeSeries,
        frameRateTimestamps: SentryFrameInfoTimeSeries
    ) {
        
    #if SENTRY_NO_UIKIT
        let warningText = "SentryScreenFrames only works with UIKit enabled. Ensure you're using the right configuration of Sentry that links UIKit."
        SentrySDKLog.warning(warningText)
        assertionFailure(warningText)
    #endif // SENTRY_NO_UIKIT
        self.total = total
        self.frozen = frozen
        self.slow = slow
        self.slowFrameTimestamps = slowFrameTimestamps
        self.frozenFrameTimestamps = frozenFrameTimestamps
        self.frameRateTimestamps = frameRateTimestamps
        super.init()
    }
#endif // os(iOS)
    
    // MARK: - NSObject Overrides
    
    public override var description: String {
        var result = "Total frames: \(total); slow frames: \(slow); frozen frames: \(frozen)"
        
#if os(iOS)
        result += "\nslowFrameTimestamps: \(slowFrameTimestamps)"
        result += "\nfrozenFrameTimestamps: \(frozenFrameTimestamps)"
        result += "\nframeRateTimestamps: \(frameRateTimestamps)"
#endif // os(iOS)
        
        return result
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SentryScreenFrames else { return false }
        
        let basicPropertiesEqual = other.total == self.total 
            && other.frozen == self.frozen 
            && other.slow == self.slow
        
#if os(iOS)
        let timestampsEqual = NSArray(array: other.slowFrameTimestamps).isEqual(self.slowFrameTimestamps)
            && NSArray(array: other.frozenFrameTimestamps).isEqual(self.frozenFrameTimestamps)
            && NSArray(array: other.frameRateTimestamps).isEqual(self.frameRateTimestamps)
        
        return basicPropertiesEqual && timestampsEqual
#else
        return basicPropertiesEqual
#endif // os(iOS)
    }
    
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(total)
        hasher.combine(frozen)
        hasher.combine(slow)
        
#if os(iOS)
        hasher.combine(NSArray(array: slowFrameTimestamps))
        hasher.combine(NSArray(array: frozenFrameTimestamps))
        hasher.combine(NSArray(array: frameRateTimestamps))
#endif // os(iOS)
        
        return hasher.finalize()
    }

    public func copy(with zone: NSZone? = nil) -> Any {
#if SENTRY_NO_UIKIT
        let warningText = "SentryScreenFrames only works with UIKit enabled. Ensure you're using the right configuration of Sentry that links UIKit."
        SentrySDKLog.warning(warningText)
        assertionFailure(warningText)
#endif // SENTRY_NO_UIKIT
        
#if os(iOS)
        return SentryScreenFrames(
            total: total,
            frozen: frozen,
            slow: slow,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
        #else
        return SentryScreenFrames(
            total: total,
            frozen: frozen,
            slow: slow
        )
        #endif // os(iOS
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS))
