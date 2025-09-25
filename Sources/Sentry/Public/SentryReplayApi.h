#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplayApi : NSObject
SENTRY_NO_INIT

/**
 * Marks this view to be masked during replays.
 *
 * When this method is called, the specified view will be masked (redacted) in session replays
 * to protect sensitive information. The view's content will appear as a solid rectangle in
 * the replay instead of showing the actual content.
 *
 * @param view The UIView to mask in session replays.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)maskView:(UIView *)view NS_SWIFT_NAME(maskView(_:));

/**
 * Marks this view to not be masked during redact step of session replay.
 *
 * When this method is called, the specified view will be excluded from masking during session
 * replays, even if it would normally be masked based on the replay configuration. This allows
 * specific views to remain visible in replays when they contain non-sensitive information.
 *
 * @param view The UIView to exclude from masking in session replays.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)unmaskView:(UIView *)view NS_SWIFT_NAME(unmaskView(_:));

/**
 * Pauses the replay.
 *
 * Temporarily stops recording frames for the session replay. The replay can be resumed
 * later by calling resume. This is useful for temporarily suspending replay recording
 * during sensitive operations or when the app goes into the background.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)pause;

/**
 * Resumes the ongoing replay.
 *
 * Resumes recording frames for the session replay after it was paused. If no replay
 * session is currently active, this method has no effect.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)resume;

/**
 * Start recording a session replay if not started.
 *
 * Manually starts a session replay recording. If session replay is already running,
 * this method has no effect. This is useful for manually controlling when replay
 * recording begins, independent of the automatic session management.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)start;

/**
 * Stop the current session replay recording.
 *
 * Permanently stops the current session replay recording and clears any cached frames.
 * To restart recording, you must call start again. This is useful for completely
 * terminating replay functionality.
 *
 * @note This method is thread-safe and can be called from any thread.
 */
- (void)stop;

/**
 * Shows an overlay on the app to debug session replay masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for the session replay.
 * This will only work if the debugger is attached and it will
 * cause some slow frames.
 *
 * @note This method is thread-safe and can be called from any thread.
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
 * @param opacity The opacity of the overlay (0.0 to 1.0).
 *
 * @note This method is thread-safe and can be called from any thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)showMaskPreview:(CGFloat)opacity;

/**
 * Removes the overlay that shows replay masking.
 *
 * Hides the mask preview overlay that was previously shown by calling showMaskPreview.
 * If no overlay is currently displayed, this method has no effect.
 *
 * @note This method is thread-safe and can be called from any thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)hideMaskPreview;

@end

NS_ASSUME_NONNULL_END

#endif
