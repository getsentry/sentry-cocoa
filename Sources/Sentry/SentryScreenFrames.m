#import <SentryScreenFrames.h>

#if SENTRY_HAS_UIKIT

@implementation SentryScreenFrames

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    return [self initWithTotal:total frozen:frozen slow:slow timestamps:@[]];
#    else
    if (self = [super init]) {
        _total = total;
        _slow = slow;
        _frozen = frozen;
    }

    return self;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)initWithTotal:(NSUInteger)total
                       frozen:(NSUInteger)frozen
                         slow:(NSUInteger)slow
                   timestamps:(SentryFrameTimestampInfo *)timestamps
{
    if (self = [super init]) {
        _total = total;
        _slow = slow;
        _frozen = frozen;
        _timestamps = timestamps;
    }

    return self;
}
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

#endif
