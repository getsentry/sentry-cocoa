#import "SentryStoredCrashReportProcessor.h"

#if !ENABLE_KSCRASH
#    import "SentryCrashReportConverter.h"
#endif
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

NSErrorDomain const SentryStoredCrashReportProcessorErrorDomain
    = @"io.sentry.crash-report-processor";
NSString *const SENTRYCRASH_REPORT_ATTACHMENTS_ITEM = @"attachments";

@interface SentryStoredCrashReportProcessor ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryStoredCrashReportProcessor

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
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

#if ENABLE_KSCRASH
    // In KSCrash mode, SentryCrashReportConverter is not compiled in; crash reports are
    // handled by KSCrash directly. This path should never be reached in practice.
    return [self failWithError:error
                          code:SentryStoredCrashReportProcessorErrorConversionFailed
                   description:@"Crash report processing is not supported in KSCrash mode."];
#else
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

        SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDKInternal.currentHub.scope];
        for (NSString *attachmentPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM] ?: @[]) {
            [scope addCrashReportAttachmentInPath:attachmentPath];
        }

        [SentrySDKInternal captureFatalEvent:event withScope:scope];
        return YES;
    } @catch (NSException *exception) {
        return [self
            failWithError:error
                     code:SentryStoredCrashReportProcessorErrorConversionFailed
              description:[NSString stringWithFormat:@"The crash report could not be processed: %@",
                              exception.reason ?: exception.name]];
    }
#endif
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
