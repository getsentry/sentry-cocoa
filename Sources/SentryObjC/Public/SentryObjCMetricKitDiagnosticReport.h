#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

/// The MetricKit diagnostic reports the SDK can capture as events.
typedef NS_OPTIONS(NSUInteger, SentryObjCMetricKitDiagnosticReport) {
    /// No diagnostic report. Disables the MetricKit integration.
    SentryObjCMetricKitDiagnosticReportNone = 0,
    /// A crash of the app, reported by @c MXCrashDiagnostic.
    /// @warning The SDK's crash handler already reports crashes. Enabling this report sends the
    /// crashes MetricKit reports in addition, so the same crash can show up twice.
    SentryObjCMetricKitDiagnosticReportCrash = 1 << 0,
    /// A hang of the main thread, reported by @c MXHangDiagnostic.
    SentryObjCMetricKitDiagnosticReportHang = 1 << 1,
    /// A CPU usage exception, reported by @c MXCPUExceptionDiagnostic.
    SentryObjCMetricKitDiagnosticReportCPUException = 1 << 2,
    /// A disk write exception, reported by @c MXDiskWriteExceptionDiagnostic.
    SentryObjCMetricKitDiagnosticReportDiskWriteException = 1 << 3,
};

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
