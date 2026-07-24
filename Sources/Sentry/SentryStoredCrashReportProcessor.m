#import "SentryStoredCrashReportProcessor.h"

#import "SentryClient+Private.h"
#import "SentryCrash.h"
#import "SentryCrashReportConverter.h"
#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentryHub.h"
#import "SentryId.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain
    = @"io.sentry.crash-report-processor";

@interface SentryStoredCrashReportProcessor ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, assign) BOOL preserveCrashedSessionOnCaptureFailure;

@end

@implementation SentryStoredCrashReportProcessor

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    return [self initWithInAppLogic:inAppLogic preserveCrashedSessionOnCaptureFailure:NO];
}

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
    preserveCrashedSessionOnCaptureFailure:(BOOL)preserveCrashedSessionOnCaptureFailure
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.preserveCrashedSessionOnCaptureFailure = preserveCrashedSessionOnCaptureFailure;
    }
    return self;
}

- (BOOL)processReport:(NSDictionary *)report error:(NSError **)error
{
    if (![report isKindOfClass:NSDictionary.class]) {
        return [self failWithError:error
                              code:SentryStoredCrashReportProcessorErrorUnsupportedReport
                       description:@"The crash report is not a dictionary."];
    }

    if ([SentrySDKInternal.currentHub getClient] == nil) {
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
        SentryHubInternal *hub = SentrySDKInternal.currentHub;
        SentryClientInternal *client = [hub getClient];
        if (client == nil) {
            return
                [self failWithError:error
                               code:SentryStoredCrashReportProcessorErrorMissingClient
                        description:@"No Sentry client is available to capture the crash report."];
        }

        SentryScope *scope = [[SentryScope alloc] initWithScope:hub.scope];
        for (NSString *attachmentPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM] ?: @[]) {
            [scope addCrashReportAttachmentInPath:attachmentPath];
        }

        SentryId *eventId =
            [hub captureFatalEventWithResult:event
                                      withScope:scope
                preserveCrashedSessionOnFailure:self.preserveCrashedSessionOnCaptureFailure];
        // An empty ID alone does not imply a retryable failure: an active client can intentionally
        // discard an event, for example through beforeSend. Retry only if the client was disabled
        // by configuration, closed, or unbound from the hub before accepting the report.
        if ([eventId isEqual:SentryId.empty]
            && ([client isDisabled] || [hub getClient] != client)) {
            return [self failWithError:error
                                  code:SentryStoredCrashReportProcessorErrorMissingClient
                           description:@"The Sentry client became unavailable before accepting the "
                                       @"crash report."];
        }
        return YES;
    } @catch (NSException *exception) {
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
