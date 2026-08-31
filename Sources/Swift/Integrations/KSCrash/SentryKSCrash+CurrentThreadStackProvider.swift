#if SDK_V10
internal import KSCrashRecordingCore
import Foundation

extension SentryKSCrash {
    /// Captures SDK-side current-thread stacks with KSCrash RecordingCore.
    ///
    /// This capability is independent of crash-handler installation because SDK clients also
    /// capture current-thread stacks for nonfatal events.
    @_spi(Private) public typealias CurrentThreadStackProvider = SentryKSCrashCurrentThreadStackProvider
}

/// An ObjC-accessible adapter for KSCrash RecordingCore current-thread capture.
@_spi(Private)
@objc(SentryKSCrashCurrentThreadStackProvider)
public final class SentryKSCrashCurrentThreadStackProvider: NSObject {
    /// Configures Swift async continuation stitching for SDK-side current-thread captures.
    @objc public static func setSwiftAsyncStackTracesEnabled(_ enabled: Bool) {
        kssc_setSwiftAsyncStackTracesEnabled(enabled)
    }

    /// Returns current-thread instruction addresses in youngest-to-oldest order.
    @objc public func captureStackEntries() -> [NSNumber] {
        var cursor = KSStackCursor()
        kssc_initSelfThread(&cursor, 0)

        var entries = [NSNumber]()
        while let advanceCursor = cursor.advanceCursor, advanceCursor(&cursor) {
            entries.append(NSNumber(value: UInt64(cursor.stackEntry.address)))
        }
        return entries
    }
}
#endif // SDK_V10
