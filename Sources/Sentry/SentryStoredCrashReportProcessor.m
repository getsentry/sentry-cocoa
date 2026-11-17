#import "SentryStoredCrashReportProcessor.h"

#import "SentryCrashReportConverter.h"
#import "SentryEvent.h"
#import "SentryLogC.h"
#import "SentrySwift.h"

NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain
    = @"io.sentry.crash-report-processor";

@interface SentryStoredCrashReportProcessor ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryCrashHandlerEventSource *crashHandlerEventSource;
@property (nonatomic, assign) BOOL preserveCrashedSessionOnCaptureFailure;

@end

@implementation SentryStoredCrashReportProcessor

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                   crashHandlerEventSource:(SentryCrashHandlerEventSource *)crashHandlerEventSource
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.crashHandlerEventSource = crashHandlerEventSource;
        self.preserveCrashedSessionOnCaptureFailure = preserveCrashedSessionOnCaptureFailure;
    }
    return self;
}

- (BOOL)processReport:(NSDictionary *)report error:(NSError **)error
{
    return [self processReport:report
                 beforeCapture:^NSError *_Nullable { return nil; }
                         error:error];
}

- (BOOL)processReport:(NSDictionary *)report
        beforeCapture:(SentryStoredCrashReportProcessorBeforeCapture)beforeCapture
                error:(NSError **)error
{
    SENTRY_LOG_DEBUG(@"Processing a stored crash report.");

    if (![report isKindOfClass:NSDictionary.class]) {
        return [self failWithError:error
                              code:SentryStoredCrashReportProcessorErrorUnsupportedReport
                       description:@"The crash report is not a dictionary."];
    }

    // Checked before the conversion, so a report that can't be converted is kept until a client
    // is available instead of being reported as unprocessable.
    if (!self.crashHandlerEventSource.isAvailable) {
        return [self failWithError:error
                              code:SentryStoredCrashReportProcessorErrorMissingClient
                       description:@"No Sentry client is available to capture the crash report."];
    }

    @try {
        SentryCrashReportConverter *reportConverter =
            [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
        SentryEvent *event = [reportConverter convertReportToEvent];
        if (event == nil) {
            return
                [self failWithError:error
                               code:SentryStoredCrashReportProcessorErrorConversionFailed
                        description:@"The crash report could not be converted to a Sentry event."];
        }

        // The sink reads the hub and its client once for the whole submission, because
        // asynchronous report processing can race with SDK close. The result below distinguishes an
        // accepted event from a no-op caused by that client becoming unavailable.
        __block NSError *captureGateError = nil;
        SentryEventSourceSubmissionResult result =
            [self.crashHandlerEventSource submitEvent:event
                                          crashReport:report
                                  isRetainedOnFailure:self.preserveCrashedSessionOnCaptureFailure
                                      beforeAccepting:^BOOL {
                                          captureGateError = beforeCapture();
                                          return captureGateError == nil;
                                      }];

        if (result == SentryEventSourceSubmissionResultAccepted) {
            SENTRY_LOG_DEBUG(@"Handed a stored crash report to the Sentry client.");
            return YES;
        }
        if (result == SentryEventSourceSubmissionResultWithdrawn) {
            if (error != nil) {
                *error = captureGateError;
            }
            return NO;
        }
        return [self failWithError:error
                              code:SentryStoredCrashReportProcessorErrorMissingClient
                       description:@"The Sentry client became unavailable before accepting the "
                                   @"crash report."];
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Could not process stored crash report: %@", exception.description);
        return [self
            failWithError:error
                     code:SentryStoredCrashReportProcessorErrorConversionFailed
              description:[NSString stringWithFormat:@"The crash report could not be processed: %@",
                              exception.reason ?: exception.name]];
    }
}

- (BOOL)failWithError:(NSError **)error
                 code:(SentryStoredCrashReportProcessorError)code
          description:(NSString *)description
{
    if (error != nil) {
        *error = [NSError errorWithDomain:SentryStoredCrashReportProcessorErrorDomain
                                     code:code
                                 userInfo:@{ NSLocalizedDescriptionKey : description }];
    }
    return NO;
}

@end
