#import "SentryStoredCrashReportProcessor.h"

#import "SentryClient+Private.h"
#import "SentryCrash.h"
#import "SentryCrashReportConverter.h"
#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentryHub.h"
#import "SentryId.h"
#import "SentryLogC.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain
    = @"io.sentry.crash-report-processor";

@interface SentryStoredCrashReportProcessor ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, copy) SentryCurrentHubProvider currentHubProvider;
@property (nonatomic, assign) BOOL preserveCrashedSessionOnCaptureFailure;

@end

@implementation SentryStoredCrashReportProcessor

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                        currentHubProvider:(SentryCurrentHubProvider)currentHubProvider
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.currentHubProvider = currentHubProvider;
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

    if ([self.currentHubProvider() getClient] == nil) {
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

        // Snapshot the hub and client again after conversion because asynchronous report processing
        // can race with SDK close. The capture result below distinguishes an accepted event from a
        // no-op caused by that client becoming unavailable.
        SentryHubInternal *hub = self.currentHubProvider();
        SentryClientInternal *client = [hub getClient];
        if (client == nil) {
            return
                [self failWithError:error
                               code:SentryStoredCrashReportProcessorErrorMissingClient
                        description:@"No Sentry client is available to capture the crash report."];
        }

        SentryScope *scope = [[SentryScope alloc] initWithScope:hub.scope];
        // KSCRASH_TODO: Native KSCrash reports do not yet include screenshot or view hierarchy
        // attachment paths. Tracked in https://github.com/getsentry/sentry-cocoa/issues/8532.
        for (NSString *attachmentPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM] ?: @[]) {
            [scope addCrashReportAttachmentInPath:attachmentPath];
        }

        NSError *captureGateError = beforeCapture();
        if (captureGateError != nil) {
            if (error != nil) {
                *error = captureGateError;
            }
            return NO;
        }

        SentryId *eventId =
            [hub captureFatalEventWithResult:event
                                      withScope:scope
                preserveCrashedSessionOnFailure:self.preserveCrashedSessionOnCaptureFailure];
        if (![hub isFatalEventCaptureResultTerminal:eventId client:client]) {
            return [self failWithError:error
                                  code:SentryStoredCrashReportProcessorErrorMissingClient
                           description:@"The Sentry client became unavailable before accepting the "
                                       @"crash report."];
        }

        SENTRY_LOG_DEBUG(@"Handed a stored crash report to the Sentry client.");
        return YES;
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
