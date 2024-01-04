#import "SentrySample.h"

@implementation SentrySample

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}
@end
