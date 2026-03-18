#import <Foundation/Foundation.h>

#import "SentryDefines.h"

#if SENTRY_OBJC_REPLAY_SUPPORTED
#    import <CoreGraphics/CoreGraphics.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_OBJC_REPLAY_SUPPORTED

@class UIView;

/**
 * Session replay API for masking and controlling replay recording.
 *
 * Use this API to dynamically control which views are masked, and to
 * start/stop/pause replay recording at runtime.
 */
@interface SentryReplayApi : NSObject

/**
 * Masks a specific view in the replay.
 *
 * The view's content will be hidden in replay recordings.
 *
 * @param view The view to mask.
 */
- (void)maskView:(UIView *)view;

/**
 * Unmasks a specific view in the replay.
 *
 * The view's content will be visible in replay recordings.
 *
 * @param view The view to unmask.
 */
- (void)unmaskView:(UIView *)view;

/**
 * Pauses replay recording.
 *
 * Recording can be resumed with @c -resume.
 */
- (void)pause;

/**
 * Resumes replay recording after it was paused.
 */
- (void)resume;

/**
 * Starts replay recording.
 *
 * @note Replay is usually started automatically when sampled.
 */
- (void)start;

/**
 * Stops replay recording.
 *
 * The recorded replay will be uploaded if errors occurred.
 */
- (void)stop;

/**
 * Shows a visual preview of which views are masked.
 *
 * Useful for debugging privacy settings. Uses default opacity.
 */
- (void)showMaskPreview;

/**
 * Shows a visual preview of which views are masked with custom opacity.
 *
 * @param opacity Opacity for the mask overlay (0.0 to 1.0).
 */
- (void)showMaskPreview:(CGFloat)opacity;

/**
 * Hides the mask preview overlay.
 */
- (void)hideMaskPreview;

@end

#endif // SENTRY_OBJC_REPLAY_SUPPORTED

NS_ASSUME_NONNULL_END
