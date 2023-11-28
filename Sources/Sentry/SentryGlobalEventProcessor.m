#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"

@implementation SentryGlobalEventProcessor

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

+ (instancetype)shared
{
    static SentryGlobalEventProcessor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] initPrivate]; });
    return instance;
}

- (instancetype)initPrivate
{
    if (self = [super init]) {
        self.processors = [NSMutableArray new];
    }
    return self;
}

- (void)addEventProcessor:(SentryEventProcessor)newProcessor
{
    [self.processors addObject:newProcessor];
}

/**
 * Only for testing
 */
- (void)removeAllProcessors
{
    [self.processors removeAllObjects];
}

@end
