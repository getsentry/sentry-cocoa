#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentrySession.h"
#import "SentryWatchdogTerminationLogic.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
#if UIKIT_LINKED
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;
#endif // UIKIT_LINKED

@end

@implementation SentrySessionCrashedHandler

#if UIKIT_LINKED
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
            watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
#else
- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
#endif // UIKIT_LINKED
{
    self = [self init];
    self.crashWrapper = crashWrapper;
#if UIKIT_LINKED
    self.watchdogTerminationLogic = watchdogTerminationLogic;
#endif // UIKIT_LINKED

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashOrOOM
{
    if (self.crashWrapper.crashedLastLaunch
#if UIKIT_LINKED
        || [self.watchdogTerminationLogic isWatchdogTermination]
#endif // UIKIT_LINKED
    ) {
        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];

        if (nil == fileManager) {
            return;
        }

        SentrySession *session = [fileManager readCurrentSession];
        if (nil == session) {
            return;
        }

        NSDate *timeSinceLastCrash = [[SentryDependencyContainer.sharedInstance.dateProvider date]
            dateByAddingTimeInterval:-self.crashWrapper.activeDurationSinceLastCrash];

        [session endSessionCrashedWithTimestamp:timeSinceLastCrash];
        [fileManager storeCrashedSession:session];
        [fileManager deleteCurrentSession];
    }
}

@end
