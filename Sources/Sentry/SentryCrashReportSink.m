#if !ENABLE_KSCRASH

#import "SentryCrashReportSink.h"

#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentryStoredCrashReportProcessor.h"
#import "SentrySwift.h"

static const NSTimeInterval SENTRY_APP_START_CRASH_DURATION_THRESHOLD = 2.0;
static const NSTimeInterval SENTRY_APP_START_CRASH_FLUSH_DURATION = 5.0;

@interface SentryCrashReportSink ()

@property (nonatomic, strong) SentryStoredCrashReportProcessor *reportProcessor;
@property (nonatomic, strong) id<SentryCrashReporter> crashWrapper;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;

@end

@implementation SentryCrashReportSink

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(id<SentryCrashReporter>)crashWrapper
                     dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
{
    if (self = [super init]) {
        // SentryCrash retains its legacy batch cleanup policy, so use the default processor mode
        // that does not preserve a session after an unavailable-client capture failure. KSCrash
        // opts into session preservation because it retains retryable reports individually.
        self.reportProcessor =
            [[SentryStoredCrashReportProcessor alloc] initWithInAppLogic:inAppLogic];
        self.crashWrapper = crashWrapper;
        self.dispatchQueue = dispatchQueue;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSTimeInterval durationFromCrashStateInitToLastCrash
        = self.crashWrapper.durationFromCrashStateInitToLastCrash;
    if (durationFromCrashStateInitToLastCrash > 0
        && durationFromCrashStateInitToLastCrash <= SENTRY_APP_START_CRASH_DURATION_THRESHOLD) {
        SENTRY_LOG_WARN(@"Startup crash: detected.");

        [SentrySDKInternal setDetectedStartUpCrash:YES];

        [self sendReports:reports onCompletion:onCompletion];

        [SentrySDKInternal flush:SENTRY_APP_START_CRASH_FLUSH_DURATION];
        SENTRY_LOG_DEBUG(@"Startup crash: Finished flushing.");

    } else {
        [self.dispatchQueue
            dispatchAsyncWithBlock:^{ [self sendReports:reports onCompletion:onCompletion]; }];
    }
}

- (void)sendReports:(NSArray *)reports onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *sentReports = [[NSMutableArray alloc] init];
    for (NSDictionary *report in reports) {
        NSError *error = nil;
        if ([self.reportProcessor processReport:report error:&error]) {
            [sentReports addObject:report];
        } else {
            SENTRY_LOG_ERROR(@"Could not process crash report: %@", error.localizedDescription);
        }
    }
    if (onCompletion) {
        onCompletion(sentReports, YES, nil);
    }
}

@end

#endif 
