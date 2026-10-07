#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

#    if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#        import "SentryObjCMetricKitDiagnosticReport.h"
#    else
#        import <SentryObjC/SentryObjCMetricKitDiagnosticReport.h>
#    endif

NS_ASSUME_NONNULL_BEGIN

/// Configuration of the MetricKit integration.
@interface SentryObjCMetricKitOptions : NSObject

#    if SDK_V10
/**
 * The MetricKit diagnostic reports the SDK captures as events.
 *
 * @c SentryObjCMetricKitDiagnosticReportNone disables the MetricKit integration.
 * @note Defaults to @c SentryObjCMetricKitDiagnosticReportCPUException,
 * @c SentryObjCMetricKitDiagnosticReportDiskWriteException and
 * @c SentryObjCMetricKitDiagnosticReportHang.
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

/// Initializes MetricKit options with default values.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
