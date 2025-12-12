#import "SentryDefines.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryBaseIntegration.h"
#    import "SentryClient+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshotIntegration : SentryBaseIntegration <SentryClientAttachmentProcessor>

/**
 * Shows an overlay on the app to debug screenshot masking.
 *
 * By calling this function an overlay will appear covering the parts
 * of the app that will be masked for screenshots.
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
 * Removes the overlay that shows screenshot masking.
 *
 * @note This method must be called from the main thread.
 *
 * @warning This is an experimental feature and may still have bugs.
 * Do not use this in production.
 */
- (void)hideMaskPreview;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
