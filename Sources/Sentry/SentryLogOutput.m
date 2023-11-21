#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogOutput

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (void)log:(NSString *)message
{
    NSLog(@"%@", message);
}

@end

NS_ASSUME_NONNULL_END
