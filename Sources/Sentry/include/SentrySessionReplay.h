#import "SentryClient+Private.h"
#import "SentryEvent.h"
#import "SentryReplaySettings.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySessionReplay : NSObject <SentryClientAttachmentProcessor>

- (instancetype)initWithSettings:(SentryReplaySettings *)replaySettings;

/**
 * Start recording the session using rootView as image source.
 * If full is @c YES, we transmit the entire session to sentry.
 */
- (void)start:(UIView *)rootView fullSession:(BOOL)full;

/**
 * Stop recording the session replay
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
