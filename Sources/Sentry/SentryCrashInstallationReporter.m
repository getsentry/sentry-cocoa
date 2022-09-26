#import "SentryCrashInstallationReporter.h"
#import "SentryCrash.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashReportSink.h"
#import "SentryDefines.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCrashInstallationReporter ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;

@end

@implementation SentryCrashInstallationReporter

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
                      crashWrapper:(SentryCrashWrapper *)crashWrapper
{
    if (self = [super initWithRequiredProperties:[NSArray new]]) {
        self.inAppLogic = inAppLogic;
        self.crashWrapper = crashWrapper;
    }
    return self;
}

- (id<SentryCrashReportFilter>)sink
{
    return [[SentryCrashReportSink alloc] initWithInAppLogic:self.inAppLogic
                                                crashWrapper:self.crashWrapper];
}

- (void)sendAllReports
{
    [self sendAllReportsWithCompletion:NULL];
}

- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    [super
        sendAllReportsWithCompletion:^(NSArray *filteredReports, BOOL completed, NSError *error) {
            if (nil != error) {
                SENTRY_LOG_ERROR(@"%@", error.localizedDescription);
            }
            SENTRY_LOG_DEBUG(@"Sent %lu crash report(s)", (unsigned long)filteredReports.count);
            if (completed && onCompletion) {
                onCompletion(filteredReports, completed, error);
            }
        }];
}

@end

NS_ASSUME_NONNULL_END
