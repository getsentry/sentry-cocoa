#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/** An array of dictionaries that each contain a start and end timestamp for a rendered frame. */
typedef NSArray<NSDictionary<NSString *, NSNumber *> *> SentryFrameTimestampInfo;

@interface SentryScreenFrames : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTotal:(NSUInteger)total frozen:(NSUInteger)frozen slow:(NSUInteger)slow;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)initWithTotal:(NSUInteger)total
                       frozen:(NSUInteger)frozen
                         slow:(NSUInteger)slow
                   timestamps:(SentryFrameTimestampInfo *)timestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@property (nonatomic, assign, readonly) NSUInteger total;
@property (nonatomic, assign, readonly) NSUInteger frozen;
@property (nonatomic, assign, readonly) NSUInteger slow;

#    if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, copy, readonly) SentryFrameTimestampInfo *timestamps;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

#endif

NS_ASSUME_NONNULL_END
