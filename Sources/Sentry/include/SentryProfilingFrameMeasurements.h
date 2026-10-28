#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfilingFrameMeasurements : NSObject

@property (nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, NSNumber *> *> *slowFrameTimestamps;
@property (nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, NSNumber *> *> *frozenFrameTimestamps;
@property (nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, NSNumber *> *> *frameRateTimestamps;

- (instancetype)initWithSlowFrameTimestamps:
                    (NSArray<NSDictionary<NSString *, NSNumber *> *> *)slowFrameTimestamps
                      frozenFrameTimestamps:
                          (NSArray<NSDictionary<NSString *, NSNumber *> *> *)frozenFrameTimestamps
                        frameRateTimestamps:
                            (NSArray<NSDictionary<NSString *, NSNumber *> *> *)frameRateTimestamps;
SENTRY_NO_INIT

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED && SENTRY_HAS_UIKIT
