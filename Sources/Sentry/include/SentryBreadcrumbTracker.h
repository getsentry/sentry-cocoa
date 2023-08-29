#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryBreadcrumbDelegate;

@interface SentryBreadcrumbTracker : NSObject

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate;
- (void)startSwizzle;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
