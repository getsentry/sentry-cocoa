#if SENTRY_HAS_UIKIT

#    import "SentryANRTracker.h"
#    import "SentryIntegrationProtocol.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryANRTrackingIntegration
    : NSObject <SentryIntegrationProtocol, SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END

#endif
