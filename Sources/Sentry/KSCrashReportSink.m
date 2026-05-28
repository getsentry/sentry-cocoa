#import "KSCrashReportSink.h"
#import "SentryClient.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
@import KSCrashRecording;

static const NSTimeInterval SENTRY_APP_START_CRASH_DURATION_THRESHOLD = 2.0;
static const NSTimeInterval SENTRY_APP_START_CRASH_FLUSH_DURATION = 5.0;

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
    // KSCrash tracks active time since the last crash; use this as the equivalent of
    // durationFromCrashStateInitToLastCrash for startup-crash detection.
    NSTimeInterval activeDurationSinceLastCrash
        = KSCrash.sharedInstance.activeDurationSinceLastCrash;
    if (activeDurationSinceLastCrash > 0
        && activeDurationSinceLastCrash <= SENTRY_APP_START_CRASH_DURATION_THRESHOLD) {
        SENTRY_LOG_WARN(@"Startup crash: detected.");

        [SentrySDKInternal setDetectedStartUpCrash:YES];

        [self sendReports:reports onCompletion:onCompletion];

        [SentrySDKInternal flush:SENTRY_APP_START_CRASH_FLUSH_DURATION];
        SENTRY_LOG_DEBUG(@"Startup crash: Finished flushing.");
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{ [self sendReports:reports onCompletion:onCompletion]; });
    }
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
        KSCrashReportConverter *reportConverter =
            [[KSCrashReportConverter alloc] initWithReport:(KSCrashReportDictionary *)report inAppLogic:self.inAppLogic];
        if (nil != [SentrySDKInternal.currentHub getClient]) {
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
    // KSCrashReportFilterCompletion signature: (NSArray<id<KSCrashReport>> *, NSError *)
    // Note: the legacy SentryCrashReportFilterCompletion had an additional BOOL completed
    // parameter; KSCrash v2 omits it.
    if (onCompletion) {
        onCompletion(sentReports, nil);
    }
}

- (void)handleConvertedEvent:(SentryEvent *)event
                      report:(id<KSCrashReport>)report
                 sentReports:(NSMutableArray<id<KSCrashReport>> *)sentReports
{
    [sentReports addObject:report];
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDKInternal.currentHub.scope];

    // TODO: KSCrash v2 does not provide an attachment mechanism in the report dictionary.
    // The legacy SentryCrashReportSink read file paths from
    // SENTRYCRASH_REPORT_ATTACHMENTS_ITEM ("attachments") injected by our SentryCrash fork.
    // Upstream KSCrash 2.x has no equivalent key; attachment forwarding is not supported
    // until KSCrash exposes a custom metadata channel.

    [SentrySDKInternal captureFatalEvent:event withScope:scope];
}

@end
