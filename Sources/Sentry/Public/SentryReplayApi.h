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
 * Marks this view to be masked during replays.
 */
- (void)maskView:(UIView *)view NS_SWIFT_NAME(maskView(_:));

/**
 * Marks this view to not be masked during redact step of session replay.
 */
- (void)unmaskView:(UIView *)view NS_SWIFT_NAME(unmaskView(_:));

/**
 * Pauses the replay.
 */
- (void)pause;

/**
 * Resumes the ongoing replay.
 */
- (void)resume;

/**
 * Start recording a session replay if not started.
 */
- (void)start;

/**
 * Stop the current session replay recording.
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif
