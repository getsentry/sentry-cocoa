#import <Foundation/Foundation.h>

#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import <SentryWithoutUIKit/SentryDefines.h>
#endif

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class UIView;

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplayApi : NSObject

/**
 * Marks this view to be redacted during replays.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)redactView:(UIView *)view NS_SWIFT_NAME(redactView(_:));

/**
 * Marks this view to be ignored during redact step of session replay.
 * All its content will be visible in the replay.
 *
 * @warning This is an experimental feature and may still have bugs.
 */
- (void)ignoreView:(UIView *)view NS_SWIFT_NAME(ignoreView(_:));

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
