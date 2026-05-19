#import <Foundation/Foundation.h>

#import "SentryOptions.h"

@class SentryObjCMetric;

// Forward declarations of SentryObjCBridge (see SentryObjCSDK.m for the full
// rationale).  Signature drift is only caught at link time / runtime — a
// shared @protocol in SentryObjCCompat would provide compile-time safety.
//
// NOTE: we cannot import a shared bridge-protocol header here even if one
// existed, because it would pull in @class SentryOptions and trigger the
// Sentry module import — creating "different definitions in different modules"
// errors with the hand-written SentryOptions.h imported above.
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
