#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
#    import <UIKit/UIKit.h>

@class SentryReplayOptions;
@class SentryEvent;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(16.0), tvos(16.0))
@interface SentrySessionReplay : NSObject

- (instancetype)initWithSettings:(SentryReplayOptions *)replaySettings;

/**
 * Start recording the session using rootView as image source.
 * If full is @c YES, we transmit the entire session to sentry.
 */
- (void)start:(UIView *)rootView fullSession:(BOOL)full;

/**
 * Stop recording the session replay
 */
- (void)stop;

- (void)replayForEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
#endif // SENTRY_HAS_UIKIT
