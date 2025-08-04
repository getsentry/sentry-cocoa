#import "SentryFeedbackAPI.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

// Helper category to allow us to create an instance of SentryFeedbackAPI` within the SDK.

@interface SentryFeedbackAPI ()

+ (instancetype)newInstance;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
