#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
#    if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#        import "SentryObjCMetricKitDiagnosticReport.h"
#    else
#        import <SentryObjC/SentryObjCMetricKitDiagnosticReport.h>
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
#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

/// How hang diagnostics are reported. Defaults to SentryObjCMetricKitHangReportingModeLegacy.
/// Configure before starting the SDK. Other diagnostic types are unaffected.
@property (nonatomic) SentryObjCMetricKitHangReportingMode hangReportingMode;

/**
 * Whether watchdog termination events wait for MetricKit to explain the termination.
 *
 * When enabled, the SDK holds a watchdog termination event for up to 30 seconds after launch, or
 * until the app moves to the background. When MetricKit delivers a crash or memory exception
 * diagnostic of the terminated run in that time, the event gets its stack trace. A crash that
 * wasn't a watchdog termination is sent as a crash instead. Otherwise the event is sent unchanged.
 * Only applies on iOS 17 and later and on visionOS while MetricKit diagnostic reports are enabled.
 * @note Defaults to @c NO.
 */
@property (nonatomic) BOOL enrichWatchdogTerminations;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
