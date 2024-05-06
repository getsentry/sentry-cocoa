#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
#    import <UIKit/UIKit.h>

@class SentryReplayOptions;
@class SentryEvent;
@class SentryCurrentDateProvider;
@class SentryDisplayLinkWrapper;
@class SentryVideoInfo;
@class SentryId;

@protocol SentryRandom;
@protocol SentryRedactOptions;
@protocol SentryViewScreenshotProvider;
@protocol SentryReplayVideoMaker;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySessionReplay : NSObject

@property (nonatomic, strong, readonly) SentryId *sessionReplayId;

- (instancetype)initWithSettings:(SentryReplayOptions *)replayOptions
                replayFolderPath:(NSURL *)folderPath
              screenshotProvider:(id<SentryViewScreenshotProvider>)photographer
                     replayMaker:(id<SentryReplayVideoMaker>)replayMaker
                    dateProvider:(SentryCurrentDateProvider *)dateProvider
                          random:(id<SentryRandom>)random
              displayLinkWrapper:(SentryDisplayLinkWrapper *)displayLinkWrapper;

/**
 * Start recording the session using rootView as image source.
 * If full is @c YES, we transmit the entire session to sentry.
 */
- (void)start:(UIView *)rootView fullSession:(BOOL)full;

/**
 * Stop recording the session replay
 */
- (void)stop;

/**
 * Captures a replay for given event.
 */
- (void)captureReplayForEvent:(SentryEvent *)event;

/**
 * Captures a replay. This method is used by the Hybrid SDKs.
 */
- (BOOL)captureReplay;

@end

NS_ASSUME_NONNULL_END
#endif // SENTRY_HAS_UIKIT
