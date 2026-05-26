#import "KSCrashReportSink.h"
#import "KSCrashReportConverter.h"
#import "SentryClient.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

@interface KSCrashReportSink ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation KSCrashReportSink

- (instancetype)initWithInAppLogic:(id)inAppLogic
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
    }
    return self;
}

- (void)filterReports:(NSArray<id<KSCrashReport>> *)reports
         onCompletion:(nullable KSCrashReportFilterCompletion)onCompletion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{ [self sendReports:reports onCompletion:onCompletion]; });
}

- (void)sendReports:(NSArray<id<KSCrashReport>> *)reports
       onCompletion:(nullable KSCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<KSCrashReport>> *sentReports = [[NSMutableArray alloc] init];
    for (id<KSCrashReport> report in reports) {
        if (![report isKindOfClass:[KSCrashReportDictionary class]]) {
            SENTRY_LOG_WARN(@"KSCrashReportSink: skipping non-dictionary report of type %@",
                NSStringFromClass([report class]));
            continue;
        }
        NSDictionary *dict = ((KSCrashReportDictionary *)report).value;
        KSCrashReportConverter *reportConverter =
            [[KSCrashReportConverter alloc] initWithReport:dict inAppLogic:self.inAppLogic];
        if (nil != [SentrySDKInternal.currentHub getClient]) {
            SentryEvent *event = [reportConverter convertReportToEvent];
            if (nil != event) {
                [sentReports addObject:report];
                SentryScope *scope =
                    [[SentryScope alloc] initWithScope:SentrySDKInternal.currentHub.scope];
                [SentrySDKInternal captureFatalEvent:event withScope:scope];
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
        onCompletion(sentReports, nil);
    }
}

@end
