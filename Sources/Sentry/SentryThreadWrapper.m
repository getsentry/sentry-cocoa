#import "SentryThreadWrapper.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryThreadWrapper

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (void)sleepForTimeInterval:(NSTimeInterval)timeInterval
{
    [NSThread sleepForTimeInterval:timeInterval];
}

- (void)threadStarted:(NSUUID *)threadID;
{
    // No op. Only needed for testing.
}

- (void)threadFinished:(NSUUID *)threadID
{
    // No op. Only needed for testing.
}

+ (void)onMainThread:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        SENTRY_LOG_DEBUG(@"Already on main thread.");
        block();
    } else {
        SENTRY_LOG_DEBUG(@"Dispatching asynchronously to main queue.");
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end

NS_ASSUME_NONNULL_END
