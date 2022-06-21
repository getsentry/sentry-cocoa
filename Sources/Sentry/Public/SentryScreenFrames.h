#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/** An array of dictionaries that each contain a start and end timestamp for a rendered frame. */
typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> SentryFrameTimestampInfo;

@interface SentryScreenFrames : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTotal:(NSUInteger)total
                       frozen:(NSUInteger)frozen
                         slow:(NSUInteger)slow
                   timestamps:(SentryFrameTimestampInfo *)timestamps;

@property (nonatomic, assign, readonly) NSUInteger total;
@property (nonatomic, assign, readonly) NSUInteger frozen;
@property (nonatomic, assign, readonly) NSUInteger slow;
@property (nonatomic, copy, readonly) SentryFrameTimestampInfo *timestamps;

@end

#endif

NS_ASSUME_NONNULL_END
