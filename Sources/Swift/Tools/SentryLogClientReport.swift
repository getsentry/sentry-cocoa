// swiftlint:disable missing_docs
import Foundation

extension SentryLog {
    /// Fallback for when a log can't be serialized. A typical enriched log is ~646 bytes; the
    /// client reports spec only needs an approximation.
    private static let defaultSerializedByteCount: UInt = 512

    func serializedByteCount() -> UInt {
        do {
            return UInt(try encodeToJSONData(data: self).count)
        } catch {
            SentrySDKLog.debug("Failed to serialize log for log_byte client report: \(error)")
            return SentryLog.defaultSerializedByteCount
        }
    }
}

/// Objective-C bridge for `SentryLog.serializedByteCount()`.
@objc @_spi(Private) public class SentryLogClientReport: NSObject {
    @objc(serializedByteCountForLog:)
    public static func serializedByteCount(for log: SentryLog) -> UInt {
        log.serializedByteCount()
    }
}
// swiftlint:enable missing_docs
