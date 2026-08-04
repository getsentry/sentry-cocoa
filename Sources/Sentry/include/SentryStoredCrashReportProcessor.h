#import "SentryDefines.h"

@class SentryHubInternal;
@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

typedef SentryHubInternal *_Nonnull (^SentryCurrentHubProvider)(void);

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

/**
 * @param currentHubProvider Resolves the current hub at each processing stage so asynchronous
 * processing does not retain a hub across SDK lifecycle changes.
 * @param preserveCrashedSessionOnCaptureFailure Set to YES only when the caller retains retryable
 * reports. Use NO to preserve the legacy SentryCrash cleanup behavior.
 */
- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic
                        currentHubProvider:(SentryCurrentHubProvider)currentHubProvider
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure;

/**
 * Processes one dictionary crash report.
 * @return YES after the converted fatal event has been handed to the Sentry client.
 */
- (BOOL)processReport:(NSDictionary *)report
                error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NAME(process(report:));

@end

NS_ASSUME_NONNULL_END
