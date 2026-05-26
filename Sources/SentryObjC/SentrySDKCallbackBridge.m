#import <Foundation/Foundation.h>

#import "SentryOptions.h"

@class SentryObjCMetric;

// Forward-declare bridge methods without importing SentryObjCBridging.h, which
// would pull in @class SentryOptions and trigger the Sentry module import —
// creating "different definitions in different modules" errors with the
// hand-written SentryOptions.h above.
@interface SentryObjCBridge : NSObject
+ (void)bridgeBeforeSendMetricForOptions:(SentryOptions *)options
                                callback:(SentryObjCMetric *_Nullable (^)(
                                             SentryObjCMetric *_Nonnull))callback;
#if SENTRY_OBJC_REPLAY_SUPPORTED
+ (void)bridgeReplayNetworkDetailAllowUrlsForReplayOptions:(SentryReplayOptions *)replayOptions
                                                      urls:(NSArray *)urls;
+ (void)bridgeReplayNetworkDetailDenyUrlsForReplayOptions:(SentryReplayOptions *)replayOptions
                                                     urls:(NSArray *)urls;
#endif
@end

void
SentryBridgeCallbacksForOptions(SentryOptions *options)
{
    SentryBeforeSendMetricCallback metricCallback = options.beforeSendMetric;
    if (metricCallback) {
        [SentryObjCBridge bridgeBeforeSendMetricForOptions:options callback:metricCallback];
    }
#if SENTRY_OBJC_REPLAY_SUPPORTED
    NSArray *allowUrls = options.sessionReplay.networkDetailAllowUrls;
    if (allowUrls.count > 0) {
        [SentryObjCBridge bridgeReplayNetworkDetailAllowUrlsForReplayOptions:options.sessionReplay
                                                                        urls:allowUrls];
    }
    NSArray *denyUrls = options.sessionReplay.networkDetailDenyUrls;
    if (denyUrls.count > 0) {
        [SentryObjCBridge bridgeReplayNetworkDetailDenyUrlsForReplayOptions:options.sessionReplay
                                                                       urls:denyUrls];
    }
#endif
}
