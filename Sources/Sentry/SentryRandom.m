#import "SentryRandom.h"

@implementation SentryRandom

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)init
{
    if (self = [super init]) {
        srand48(time(0)); // drand seed initializer
    }
    return self;
}

- (double)nextNumber
{
    return drand48();
}

@end
