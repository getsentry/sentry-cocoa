
#ifndef SentryUIApplication_Private_h
#define SentryUIApplication_Private_h

#import "SentryDefines.h"
#import "SentryUIApplication.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIApplication ()

- (NSArray<UIViewController *> *)relevantViewControllers;

@end

NS_ASSUME_NONNULL_END

#endif /* SentryUIApplication_Private_h */
#endif
