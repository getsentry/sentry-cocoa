/// A snapshot of a detected main run loop delay, reported to observers each polling interval while ongoing
/// and once more with ``isOngoing`` set to `false` when the delay ends.
struct SentryRunLoopDelay {
    let duration: TimeInterval
    let isOngoing: Bool
}
