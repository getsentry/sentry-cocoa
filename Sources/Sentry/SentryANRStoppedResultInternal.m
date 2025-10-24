#import "SentryANRStoppedResultInternal.h"

@implementation SentryANRStoppedResultInternal

- (instancetype)initWithMinDuration:(NSTimeInterval)minDuration
                        maxDuration:(NSTimeInterval)maxDuration
{
    if (self = [super init]) {
        _minDuration = minDuration;
        _maxDuration = maxDuration;
        return self;
    }
    return nil;
}

@end
