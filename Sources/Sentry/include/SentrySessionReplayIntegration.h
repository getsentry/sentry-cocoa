#import "SentryBaseIntegration.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_TARGET_REPLAY_SUPPORTED

@protocol SentryReplayBreadcrumbConverter;
@protocol SentryViewScreenshotProvider;

@interface SentrySessionReplayIntegration : SentryBaseIntegration

/**
 * The last instance of the installed integration
 */
@property (class, nonatomic, readonly, nullable) SentrySessionReplayIntegration *installed;

/**
 * Captures Replay. Used by the Hybrid SDKs.
 */
- (BOOL)captureReplay;

/**
 * Configure session replay with different breadcrumb converter
 * and screeshot provider. Used by the Hybrid SDKs.
 * If can pass nil to avoid changing the property.
 */
- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider;

- (void)pause;

- (void)resume;

@end
#endif // SENTRY_TARGET_REPLAY_SUPPORTED
NS_ASSUME_NONNULL_END
