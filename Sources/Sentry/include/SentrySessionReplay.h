#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
#    import <UIKit/UIKit.h>

@class SentryReplayOptions;
@class SentryEvent;
@class SentryCurrentDateProvider;
@class SentryDisplayLinkWrapper;
@class SentryVideoInfo;

@protocol SentryRandom;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryReplayMaker <NSObject>

- (void)addFrameWithImage:(UIImage *)image;
- (void)releaseFramesUntil:(NSDate *)date;
- (BOOL)createVideoWithDuration:(NSTimeInterval)duration
                      beginning:(NSDate *)beginning
                  outputFileURL:(NSURL *)outputFileURL
                          error:(NSError *_Nullable *_Nullable)error
                     completion:
                         (void (^)(SentryVideoInfo *_Nullable, NSError *_Nullable))completion;

@end

@protocol SentryViewScreenshotProvider <NSObject>
- (UIImage *)imageWithView:(UIView *)view;
@end

API_AVAILABLE(ios(16.0), tvos(16.0))
@interface SentrySessionReplay : NSObject

- (instancetype)initWithSettings:(SentryReplayOptions *)replayOptions
                replayFolderPath:(NSURL *)folderPath
              screenshotProvider:(id<SentryViewScreenshotProvider>)photographer
                     replayMaker:(id<SentryReplayMaker>)replayMaker
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

- (void)replayForEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
#endif // SENTRY_HAS_UIKIT
