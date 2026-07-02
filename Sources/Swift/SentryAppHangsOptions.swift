/// Configuration options for app hang detection.
///
/// - Note: These options are experimental and subject to change in future versions.
public struct AppHangsOptions {

    /// Enables the V3 app hang detection mechanism based on run loop observers.
    ///
    /// When enabled, V3 replaces V1/V2 hang tracking with an event-driven detector
    /// based on ``RunLoop`` observers. This approach is more efficient and accurate,
    /// as it avoids the overhead of continuous sampling and provides immediate
    /// notifications when a hang is detected.
    ///
    /// - Note: V3 only reports fully-blocking hangs where a single run loop iteration
    ///   exceeds ``threshold``. The non-fully-blocking category from V2 is dropped.
    public var enableV3 = false

    /// Duration before classifying as an app hang and reporting an event
    public var threshold: TimeInterval = 2.0
}
