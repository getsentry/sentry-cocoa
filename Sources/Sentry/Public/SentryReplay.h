#import <Foundation/Foundation.h>
#import <Sentry/SentryDefines.h>

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplay : NSObject

/**
 * Marks this view to be redacted during replays.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)replayRedactView:(UIView *)view;

/**
 * Marks this view to be ignored during redact step of session replay.
 * All its content will be visible in the replay.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)replayIgnoreView:(UIView *)view;

/**
 * Pauses the replay.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)pause;

/**
 * Resumes the ongoing replay.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)resume;

@end

NS_ASSUME_NONNULL_END

#endif
