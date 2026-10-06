#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Selects how MetricKit hang call stack trees are reported.
typedef NS_ENUM(NSInteger, SentryObjCMetricKitHangReportingMode) {
    /// Preserves all sampled frames and their tree metadata.
    SentryObjCMetricKitHangReportingModeLegacy = 0,
    /// Selects a representative stack using frequency, depth, and in-app frame quality.
    SentryObjCMetricKitHangReportingModeCulprit = 1,
};

/// Experimental options for MetricKit diagnostics. Requires enableMetricKit.
@interface SentryObjCMetricKitOptions : NSObject

/// How hang diagnostics are reported. Defaults to SentryObjCMetricKitHangReportingModeLegacy.
/// Configure before starting the SDK. Other diagnostic types are unaffected.
@property (nonatomic) SentryObjCMetricKitHangReportingMode hangReportingMode;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
