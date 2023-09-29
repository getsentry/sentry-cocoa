#import "SentryDefines.h"

#if UIKIT_LINKED

#    import "SentryBaseIntegration.h"
#    import "SentryIntegrationProtocol.h"

@interface SentryUIEventTrackingIntegration : SentryBaseIntegration <SentryIntegrationProtocol>

@end

#endif // UIKIT_LINKED
