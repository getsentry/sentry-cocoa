#import "SentryReachability.h"

void SentryConnectivityCallback(__unused SCNetworkReachabilityRef target,
    SCNetworkReachabilityFlags flags, __unused void *info);

@interface
SentryReachability ()

@property SCNetworkReachabilityRef sentry_reachability_ref;

@end
