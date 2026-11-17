#import "SentryDefines.h"

@class SentryCrashHandlerEventSource;
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

/**
 * Converts a dictionary crash report into a fatal Sentry event and submits it through the crash
 * handler event source, so it reaches the SDK like the reports of every other event source.
 */
@interface SentryStoredCrashReportProcessor : NSObject
SENTRY_NO_INIT

/**
 * @param crashHandlerEventSource Takes the converted events. The sink behind it resolves the
 * current hub for each of them so asynchronous processing does not retain a hub across SDK
 * lifecycle changes.
 * @param preserveCrashedSessionOnCaptureFailure Set to YES only when the caller retains retryable
 * reports. Use NO to preserve the legacy SentryCrash cleanup behavior.
 */
- (instancetype)initWithInAppLogic:(SENTRY_SWIFT_MIGRATION_ID(SentryInAppLogic))inAppLogic
                   crashHandlerEventSource:
                       (SENTRY_SWIFT_MIGRATION_ID(
                           SentryCrashHandlerEventSource))crashHandlerEventSource
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure;

/**
 * Processes one dictionary crash report.
 * @return YES after the converted fatal event has been accepted.
 */
- (BOOL)processReport:(NSDictionary *)report
                error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NAME(process(report:));

/**
 * Processes one dictionary crash report with a gate invoked after conversion and immediately
 * before the event is accepted. Returning an error from the gate withdraws the event and
 * propagates that error to the caller.
 */
- (BOOL)processReport:(NSDictionary *)report
        beforeCapture:(SentryStoredCrashReportProcessorBeforeCapture)beforeCapture
                error:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(process(report:beforeCapture:));

@end

NS_ASSUME_NONNULL_END
