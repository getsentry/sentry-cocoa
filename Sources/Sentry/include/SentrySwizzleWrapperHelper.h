#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

#endif // SENTRY_HAS_UIKIT

@class SentryNetworkTracker;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySwizzleWrapperHelper : NSObject

#if SENTRY_HAS_UIKIT
+ (void)swizzle:(void (^)(SEL action, _Nullable id target, _Nullable id sender,
                    UIEvent *_Nullable event))callback;

// Swizzle [UIViewController viewDidAppear:] to track view controller lifecycle
+ (void)swizzleViewDidAppear:(void (^)(UIViewController *viewController))callback
                      forKey:(const void *)key;

// Swizzle [UIApplication sendEvent:]
+ (void)swizzleSendEvent:(void (^)(UIEvent *_Nullable event))callback;
#endif // SENTRY_HAS_UIKIT

+ (void)swizzleURLSessionTask:(SentryNetworkTracker *)networkTracker;

@end

NS_ASSUME_NONNULL_END
