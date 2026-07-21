// swiftlint:disable missing_docs
import Foundation

fileprivate extension SentryMetric {
    /// Fallback for when a metric can't be serialized. The client reports spec only needs an
    /// approximation, matching the log counterpart in `SentryLogClientReport`.
    private static let defaultSerializedByteCount: UInt = 512

    func serializedByteCount() -> UInt {
        do {
            return UInt(try encodeToJSONData(data: self).count)
        } catch {
            SentrySDKLog.debug("Failed to serialize metric for trace_metric_byte client report: \(error)")
            return SentryMetric.defaultSerializedByteCount
        }
    }
}

/// Computes the serialized byte size of a `SentryMetric` for `trace_metric_byte` client reports.
/// Kept as a dedicated type to mirror `SentryLogClientReport` and to expose the helper for testing.
@_spi(Private) public enum SentryMetricClientReport {
    public static func serializedByteCount(for metric: SentryMetric) -> UInt {
        metric.serializedByteCount()
    }
}
// swiftlint:enable missing_docs
