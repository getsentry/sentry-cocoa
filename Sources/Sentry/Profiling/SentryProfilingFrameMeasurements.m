#import "SentryProfilingFrameMeasurements.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED && SENTRY_HAS_UIKIT

@implementation SentryProfilingFrameMeasurements

- (instancetype)initWithSlowFrameTimestamps:
                    (NSArray<NSDictionary<NSString *, NSNumber *> *> *)slowFrameTimestamps
                      frozenFrameTimestamps:
                          (NSArray<NSDictionary<NSString *, NSNumber *> *> *)frozenFrameTimestamps
                        frameRateTimestamps:
                            (NSArray<NSDictionary<NSString *, NSNumber *> *> *)frameRateTimestamps
{
    if (self = [super init]) {
        _slowFrameTimestamps = [slowFrameTimestamps copy];
        _frozenFrameTimestamps = [frozenFrameTimestamps copy];
        _frameRateTimestamps = [frameRateTimestamps copy];
    }
    return self;
}

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED && SENTRY_HAS_UIKIT
