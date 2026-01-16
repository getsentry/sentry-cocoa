@_implementationOnly import _SentryPrivate

/// Protocol for integrations that support manual flushing of buffered data.
///
/// Integrations conforming to this protocol can be flushed synchronously,
/// typically during app lifecycle events or manual flush operations.
protocol FlushableIntegration: SentryIntegrationProtocol {
    /// Flushes any buffered data synchronously.
    /// - Returns: The time taken to flush in seconds
    @discardableResult func flush() -> TimeInterval
}
