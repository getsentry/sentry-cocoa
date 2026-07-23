import Foundation

/// Objective-C compatible box for the Swift-only `SentryMetric` struct, so a metric can be passed
/// across the ObjC boundary (e.g. into `SentryClientInternal`'s client-report drop path) and
/// unwrapped again in Swift. See `SentryDataCollectionObjCOptions` for the same pattern.
@_spi(Private) @objc public final class SentryMetricObjC: NSObject {
    let wrapped: SentryMetric

    /// Creates a box around the given metric.
    @_spi(Private) public init(metric: SentryMetric) {
        self.wrapped = metric
        super.init()
    }

    /// Serialized byte size for `trace_metric_byte` client reports. Exposed for the ObjC
    /// client-report drop path, which can't call the Swift-only `SentryMetricClientReport` directly
    /// on a struct.
    @objc public func serializedByteCount() -> UInt {
        SentryMetricClientReport.serializedByteCount(for: wrapped)
    }
}
