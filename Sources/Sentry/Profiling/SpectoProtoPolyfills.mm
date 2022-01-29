#include "SpectoProtoPolyfills.h"
#import "SpectoTime.h"

@implementation SentryBacktrace

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    addresses = [NSMutableArray array];
    return self;
}

@end

@implementation SentryProfilingEntry

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    backtrace = [[SentryBacktrace alloc] init];
    return self;
}

@end

@implementation SentryProfilingTraceLogger

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    referenceUptimeNs = specto::time::getUptimeNs();
    return self;
}

@end
