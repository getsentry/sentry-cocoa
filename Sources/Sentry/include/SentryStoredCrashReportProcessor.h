#import "SentryDefines.h"

@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain;

typedef NSError *_Nullable (^SentryStoredCrashReportProcessorBeforeCapture)(void);

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
 * @param preserveCrashedSessionOnCaptureFailure Set to YES only when the caller retains retryable
 * reports. The default initializer uses NO to preserve the legacy SentryCrash cleanup behavior.
 */
- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure;

/**
 * Processes one dictionary crash report.
 * @return YES after the converted fatal event has been handed to the Sentry client.
 */
- (BOOL)processReport:(NSDictionary *)report
                error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NAME(process(report:));

/**
 * Processes one dictionary crash report with a gate invoked after conversion and immediately
 * before client capture. Returning an error from the gate declines capture and propagates that
 * error to the caller.
 */
- (BOOL)processReport:(NSDictionary *)report
        beforeCapture:(SentryStoredCrashReportProcessorBeforeCapture)beforeCapture
                error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(process(report:beforeCapture:));

@end

NS_ASSUME_NONNULL_END
