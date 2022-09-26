#import "SentryCrashReportSink.h"
#import "SentryAttachment.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#include "SentryCrashMonitor_AppState.h"
#import "SentryCrashReportConverter.h"
#import "SentryCrashWrapper.h"
#import "SentryDefines.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import "SentryScope.h"
#import "SentryThread.h"

@interface
SentryCrashReportSink ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;

@end

@implementation SentryCrashReportSink

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
        self.crashWrapper = crashWrapper;
        self.dispatchQueue = dispatchQueue;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSTimeInterval value = self.crashWrapper.durationFromCrashStateInitToLastCrash;
    if (value != 0 && value <= 3.0) {
        SENTRY_LOG_DEBUG(@"Startup crash: detected.");
        [self sendReports:reports onCompletion:onCompletion];

        [SentrySDK flush:2.0];
        SENTRY_LOG_DEBUG(@"Startup crash: Finished flushing.");

    } else {
        [self.dispatchQueue
            dispatchAsyncWithBlock:^{ [self sendReports:reports onCompletion:onCompletion]; }];
    }
}

- (void)sendReports:(NSArray *)reports onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *sentReports = [NSMutableArray new];
    for (NSDictionary *report in reports) {
        SentryCrashReportConverter *reportConverter =
            [[SentryCrashReportConverter alloc] initWithReport:report inAppLogic:self.inAppLogic];
        if (nil != [SentrySDK.currentHub getClient]) {
            SentryEvent *event = [reportConverter convertReportToEvent];
            if (nil != event) {
                [self handleConvertedEvent:event report:report sentReports:sentReports];
            }
        } else {
            SENTRY_LOG_ERROR(
                @"Crash reports were found but no [SentrySDK.currentHub getClient] is set. "
                @"Cannot send crash reports to Sentry. This is probably a misconfiguration, "
                @"make sure you set the client with [SentrySDK.currentHub bindClient] before "
                @"calling startCrashHandlerWithError:.");
        }
    }
    if (onCompletion) {
        onCompletion(sentReports, TRUE, nil);
    }
}

- (void)handleConvertedEvent:(SentryEvent *)event
                      report:(NSDictionary *)report
                 sentReports:(NSMutableArray *)sentReports
{
    [sentReports addObject:report];
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];

    if (report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
        for (NSString *ssPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
            [scope addAttachment:[[SentryAttachment alloc] initWithPath:ssPath]];
        }
    }

    [SentrySDK captureCrashEvent:event withScope:scope];
}

@end
