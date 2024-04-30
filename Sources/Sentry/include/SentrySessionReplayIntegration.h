#import "SentryBaseIntegration.h"
#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT && !TARGET_OS_VISION
@interface SentrySessionReplayIntegration : SentryBaseIntegration

/**
 * Captures Replay. Used by the Hybrid SDKs.
 */
- (void)captureReplay;

@end
#endif // SENTRY_HAS_UIKIT && !TARGET_OS_VISION
NS_ASSUME_NONNULL_END
