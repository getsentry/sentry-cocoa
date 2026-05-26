#import "SentryObjCDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_OBJC_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCReplayApi : NSObject

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

NS_ASSUME_NONNULL_END

#endif
