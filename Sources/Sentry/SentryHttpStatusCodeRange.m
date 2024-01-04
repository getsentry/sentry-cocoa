#import "SentryHttpStatusCodeRange.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryHttpStatusCodeRange

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max
{
    if (self = [super init]) {
        _min = min;
        _max = max;
    }
    return self;
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode
{
    if (self = [super init]) {
        _min = statusCode;
        _max = statusCode;
    }
    return self;
}

- (BOOL)isInRange:(NSInteger)statusCode
{
    return statusCode >= _min && statusCode <= _max;
}

@end

NS_ASSUME_NONNULL_END
