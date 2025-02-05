#import "SentryDefines.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryBaseIntegration.h"
#    import "SentryClient+Private.h"
#    import "SentryScreenshot.h"
#    import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScreenshotIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryClientAttachmentProcessor>

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
