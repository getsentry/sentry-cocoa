#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
#    if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#        import "SentryObjCMetricKitDiagnosticReport.h"
#        import "SentryObjCMetricKitMetricReport.h"
#    else
#        import <SentryObjC/SentryObjCMetricKitDiagnosticReport.h>
#        import <SentryObjC/SentryObjCMetricKitMetricReport.h>
#    endif
#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

NS_ASSUME_NONNULL_BEGIN

/// Selects how MetricKit hang call stack trees are reported.
typedef NS_ENUM(NSInteger, SentryObjCMetricKitHangReportingMode) {
    /// Preserves all sampled frames and their tree metadata.
    SentryObjCMetricKitHangReportingModeLegacy = 0,
    /// Attaches aggregated call trees as a flame graph for server-side processing.
    SentryObjCMetricKitHangReportingModeFlamegraphAttachment = 1,
};

/// Experimental options for the MetricKit integration.
@interface SentryObjCMetricKitOptions : NSObject

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
#    if SDK_V10
/**
 * The MetricKit diagnostic reports the SDK captures as events.
 *
 * @c SentryObjCMetricKitDiagnosticReportNone disables the MetricKit integration.
 * @note Defaults to @c SentryObjCMetricKitDiagnosticReportCPUException,
 * @c SentryObjCMetricKitDiagnosticReportDiskWriteException,
 * @c SentryObjCMetricKitDiagnosticReportHang and
 * @c SentryObjCMetricKitDiagnosticReportAppLaunch.
 */
#    else
/**
 * The MetricKit diagnostic reports the SDK captures as events.
 *
 * Any report other than @c SentryObjCMetricKitDiagnosticReportNone enables the MetricKit
 * integration and captures exactly these reports, regardless of @c enableMetricKit. When no report
 * is set, @c enableMetricKit decides whether the integration is enabled.
 * @note Defaults to @c SentryObjCMetricKitDiagnosticReportNone.
 */
#    endif // SDK_V10
@property (nonatomic) SentryObjCMetricKitDiagnosticReport enabledDiagnosticReports;

/**
 * The MetricKit metric reports the SDK sends as Sentry metrics.
 *
 * Any report other than @c SentryObjCMetricKitMetricReportNone enables the MetricKit integration,
 * even when no diagnostic reports are enabled. Use @c SentryObjCMetricKitMetricReportAll to send
 * every metric report.
 *
 * MetricKit delivers metric payloads about once a day, and each enabled report adds up to one
 * metric per payload, which counts towards your metrics quota.
 *
 * On macOS, MetricKit delivers metric payloads from macOS 26, and only to apps built with Xcode 26
 * or later.
 * @note Defaults to @c SentryObjCMetricKitMetricReportNone.
 */
@property (nonatomic) SentryObjCMetricKitMetricReport enabledMetricReports;
#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

/// How hang diagnostics are reported. Defaults to SentryObjCMetricKitHangReportingModeLegacy.
/// Configure before starting the SDK. Other diagnostic types are unaffected.
@property (nonatomic) SentryObjCMetricKitHangReportingMode hangReportingMode;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
