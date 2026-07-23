#import "SentryDefines.h"

@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain;

typedef NS_ERROR_ENUM(
    SentryStoredCrashReportProcessorErrorDomain, SentryStoredCrashReportProcessorError) {
    SentryStoredCrashReportProcessorErrorUnsupportedReport,
    SentryStoredCrashReportProcessorErrorMissingClient,
    SentryStoredCrashReportProcessorErrorConversionFailed,
};

/** Converts a dictionary crash report and captures it as a fatal Sentry event. */
@interface SentryStoredCrashReportProcessor : NSObject
SENTRY_NO_INIT

- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic;

/**
 * Processes one dictionary crash report.
 * @return YES after the converted fatal event has been handed to the Sentry client.
 */
- (BOOL)processReport:(NSDictionary *)report
                error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NAME(process(report:));

@end

NS_ASSUME_NONNULL_END
