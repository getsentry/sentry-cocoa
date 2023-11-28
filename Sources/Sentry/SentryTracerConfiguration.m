#import "SentryTracerConfiguration.h"

@implementation SentryTracerConfiguration

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

+ (SentryTracerConfiguration *)defaultConfiguration
{
    return [[SentryTracerConfiguration alloc] init];
}

+ (SentryTracerConfiguration *)configurationWithBlock:(void (^)(SentryTracerConfiguration *))block
{
    SentryTracerConfiguration *result = [[SentryTracerConfiguration alloc] init];

    block(result);

    return result;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.idleTimeout = 0;
        self.waitForChildren = NO;
    }
    return self;
}

@end
