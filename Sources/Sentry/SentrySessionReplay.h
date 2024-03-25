#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@class SentryReplayOptions;
@class SentryEvent;

NS_ASSUME_NONNULL_BEGIN

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
