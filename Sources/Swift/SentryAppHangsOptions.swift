/**
 * Configuration options for app hang detection.
 *
 * These options are experimental and subject to change in future versions.
 */
public struct AppHangsOptions {

    /**
     * Enables the V3 app hang detection mechanism based on run loop observers.
     *
     * When enabled, V3 replaces V1/V2 hang tracking with an event-driven detector
     * based on ``RunLoop`` observers. This approach is more efficient and accurate,
     * as it avoids the overhead of continuous sampling and provides immediate
     * notifications when a hang is detected.
     *
     * - Note: V3 only reports fully-blocking hangs where a single run loop iteration
     *   exceeds ``appHangThreshold``. The non-fully-blocking category from V2 is dropped.
     */
    public var enableV3 = false

    /**
     * Duration before classifying as an app hang and reporting an event
     */
    public var appHangThreshold: TimeInterval = 2.0

    /// Sample rate for profiling app hangs (0.0 to 1.0).
    /// When an app hang is detected, this rate determines whether
    /// stack trace sampling occurs for flamegraph generation.
    public var profilingSampleRate: Double {
        get { _profilingSampleRate }
        set { _profilingSampleRate = min(max(newValue, 0.0), 1.0) }
    }
    private var _profilingSampleRate: Double = 1.0

    /// Interval in milliseconds between main-thread stack trace samples
    /// during an app hang. Lower values give more detail but higher overhead.
    public var profilingSampleIntervalMs: Int = 100
}
