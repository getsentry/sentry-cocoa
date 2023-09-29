#import "SentryDefines.h"

#if UIKIT_LINKED

#    import "SentryBaseIntegration.h"
#    import "SentryClient+Private.h"
#    import "SentryIntegrationProtocol.h"
#    import "SentryScreenshot.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshotIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryClientAttachmentProcessor>

@end

NS_ASSUME_NONNULL_END

#endif // UIKIT_LINKED
