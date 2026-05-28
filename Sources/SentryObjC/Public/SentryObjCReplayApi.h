#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

/// API for interacting with the Session Replay feature.
@interface SentryObjCReplayApi : NSObject
SENTRY_NO_INIT

/// Marks this view to be masked during replays.
- (void)maskView:(UIView *)view;

/// Marks this view to not be masked during the redact step of session replay.
- (void)unmaskView:(UIView *)view;

/// Pauses the replay.
- (void)pause;

/// Resumes the ongoing replay.
- (void)resume;

/// Start recording a session replay if not started.
- (void)start;

/// Stop the current session replay recording.
- (void)stop;

/**
 * Shows an overlay on the app to debug session replay masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for the session replay.
 * This will only work if the debugger is attached and it will
 * cause some slow frames.
 *
 * @note This method must be called from the main thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)showMaskPreview;

/**
 * Shows an overlay on the app to debug session replay masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for the session replay.
 * This will only work if the debugger is attached and it will
 * cause some slow frames.
 *
 * @param opacity The opacity of the overlay.
 *
 * @note This method must be called from the main thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)showMaskPreview:(CGFloat)opacity;

/**
 * Removes the overlay that shows replay masking.
 *
 * @note This method must be called from the main thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)hideMaskPreview;

@end

NS_ASSUME_NONNULL_END

#endif
