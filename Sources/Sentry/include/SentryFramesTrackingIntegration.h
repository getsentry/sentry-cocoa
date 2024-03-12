#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import <Foundation/Foundation.h>
#    import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryFramesTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
