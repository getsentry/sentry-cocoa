#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryUserFeedbackConfiguration;

@interface SentryUserFeedbackIntegration : NSObject

- (instancetype)initWithConfiguration:(SentryUserFeedbackConfiguration *)configuration;

/**
 * Show the user feedback modal. This provides a way to manually show the modal at any time, if one
 * of the predefined trigger methods doesn't cover certain use cases.
 */
- (void)showModal;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
