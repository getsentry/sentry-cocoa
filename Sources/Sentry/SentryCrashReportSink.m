#import "SentryCrashReportSink.h"
#import "SentryAttachment.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#import "SentryCrashReportConverter.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import "SentryThread.h"

@implementation SentryCrashReportSink

- (void)handleConvertedEvent:(SentryEvent *)event
                 attachments:(NSArray<SentryAttachment *> *)attachments
                      report:(NSDictionary *)report
                 sentReports:(NSMutableArray *)sentReports
{
    [sentReports addObject:report];
    [SentrySDK captureCrashEvent:event attachments:attachments];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            SentryCrashReportConverter *reportConverter =
                [[SentryCrashReportConverter alloc] initWithReport:report];
            if (nil != [SentrySDK.currentHub getClient]) {
                SentryEvent *event = [reportConverter convertReportToEvent];

                if (nil != event) {
                    NSArray<SentryAttachment *> *attachments =
                        [reportConverter convertReportToAttachments];
                    [self handleConvertedEvent:event
                                   attachments:attachments
                                        report:report
                                   sentReports:sentReports];
                }
            } else {
                [SentryLog logWithMessage:@"Crash reports were found but no "
                                          @"[SentrySDK.currentHub getClient] is set. Cannot send "
                                          @"crash reports to Sentry. This is probably a "
                                          @"misconfiguration, make sure you set the client with "
                                          @"[SentrySDK.currentHub bindClient] before calling "
                                          @"startCrashHandlerWithError:."
                                 andLevel:kSentryLogLevelError];
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });
}

@end
