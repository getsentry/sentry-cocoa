#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySwizzleWrapper;

@protocol SentryBreadcrumbDelegate;

@interface SentryBreadcrumbTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper;

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;
- (void)startSwizzle;
- (void)stop;

#if SENTRY_HAS_UIKIT
/**
 * For testing.
 */
+ (BOOL)avoidSender:(id)sender forTarget:(id)target action:(NSString *)action;
#endif

@end

NS_ASSUME_NONNULL_END
