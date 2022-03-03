#import "SentryProtoPolyfills.h"
#import "SentryTime.h"

@implementation SentryProfilingTraceLogger

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    referenceUptimeNs = sentry::profiling::time::getUptimeNs();
    return self;
}

@end
