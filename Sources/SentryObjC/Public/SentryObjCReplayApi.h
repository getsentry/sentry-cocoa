#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

#if SENTRY_OBJC_REPLAY_SUPPORTED
#    import <CoreGraphics/CoreGraphics.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_REPLAY_SUPPORTED

@class UIView;

/**
 * Session replay API for masking and controlling replay recording.
 */
@interface SentryReplayApi : NSObject

- (void)maskView:(UIView *)view;
- (void)unmaskView:(UIView *)view;
- (void)pause;
- (void)resume;
- (void)start;
- (void)stop;
- (void)showMaskPreview;
- (void)showMaskPreview:(CGFloat)opacity;
- (void)hideMaskPreview;

@end

#endif // SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_END
