#import "SentryDefines.h"

@class SentryOptions, SentryDisplayLinkWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SentryFramesTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
             displayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

@property (nonatomic, assign, readonly) NSUInteger currentTotalFrames;
@property (nonatomic, assign, readonly) NSUInteger currentFrozenFrames;
@property (nonatomic, assign, readonly) NSUInteger currentSlowFrames;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
