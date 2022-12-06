#import "SentrySessionCrashedHandler.h"
#import "SentryClient+Private.h"
#import "SentryCrashWrapper.h"
#import "SentryCurrentDate.h"
#import "SentryFileManager.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentryWatchDogTerminationsLogic.h"

@interface
SentrySessionCrashedHandler ()

@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryWatchDogTerminationsLogic *watchDogTerminationsLogic;

@end

@implementation SentrySessionCrashedHandler

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
           watchDogTerminationsLogic:(SentryWatchDogTerminationsLogic *)watchDogTerminationsLogic;
{
    self = [self init];
    self.crashWrapper = crashWrapper;
    self.watchDogTerminationsLogic = watchDogTerminationsLogic;

    return self;
}

- (void)endCurrentSessionAsCrashedWhenCrashOrOOM
{
    if (self.crashWrapper.crashedLastLaunch ||
        [self.watchDogTerminationsLogic isWatchdogTermination]) {
        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];

        if (nil == fileManager) {
            return;
        }

        SentrySession *session = [fileManager readCurrentSession];
        if (nil == session) {
            return;
        }

        NSDate *timeSinceLastCrash = [[SentryCurrentDate date]
            dateByAddingTimeInterval:-self.crashWrapper.activeDurationSinceLastCrash];

        [session endSessionCrashedWithTimestamp:timeSinceLastCrash];
        [fileManager storeCrashedSession:session];
        [fileManager deleteCurrentSession];
    }
}

@end
