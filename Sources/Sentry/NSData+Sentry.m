#import "NSData+Sentry.h"

@implementation
NSData (Sentry)

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (NSData *)sentry_nullTerminated
{
    if (self == nil) {
        return nil;
    }
    NSMutableData *mutable = [NSMutableData dataWithData:self];
    [mutable appendBytes:"\0" length:1];
    return mutable;
}

@end
