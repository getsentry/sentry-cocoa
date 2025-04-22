#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around DisplayLink for testability.
 */
@interface SentryDisplayLinkWrapper : NSObject

@property (readonly, nonatomic) CFTimeInterval timestamp;

@property (readonly, nonatomic) CFTimeInterval targetTimestamp API_AVAILABLE(ios(10.0), tvos(10.0));

/**
 * Link the display link to the target and selector with the preferred frames per second.
 * @param target The target of the selector.
 * @param sel The selector to call on the target.
 * @param fps The preferred frames per second. Setting to `-1` will use the default frames per
 * second.
 */
- (void)linkWithTarget:(id)target selector:(SEL)sel preferredFramesPerSecond:(NSInteger)fps;

/**
 * Link the display link to the target and selector with the preferred frame rate range.
 * @param target The target of the selector.
 * @param sel The selector to call on the target.
 * @param preferredFrameRateRange The preferred frame rate range. Use `CAFrameRateRangeDefault` to
 * use the  default frame rate range.
 */
- (void)linkWithTarget:(id)target
                   selector:(SEL)sel
    preferredFrameRateRange:(CAFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0));

- (void)invalidate;

- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END

#endif
