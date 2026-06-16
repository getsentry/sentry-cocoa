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

/// General-purpose instance method swizzling for hybrid SDKs.
///
/// @param selector The selector to swizzle.
/// @param classToSwizzle The class containing the method.
/// @param mode 0 = always, 1 = once per class, 2 = once per class and superclasses.
/// @param key A unique key identifying this swizzle operation.
/// @param factory A block that receives a "get original IMP" block and returns the replacement
///   implementation block.
/// @return @c YES if successfully swizzled.
+ (BOOL)swizzleInstanceMethod:(SEL)selector
                      inClass:(Class)classToSwizzle
                         mode:(NSUInteger)mode
                          key:(const void *)key
                      factory:(id (^)(IMP(NS_NOESCAPE ^)(void)))factory;

+ (void)swizzleURLSessionTask:(SentryNetworkTracker *)networkTracker;

#if SENTRY_TARGET_REPLAY_SUPPORTED
// Swizzle [NSURLSession dataTaskWithURL:completionHandler:]
//         [NSURLSession dataTaskWithRequest:completionHandler:]
+ (void)swizzleURLSessionDataTasksForResponseCapture:(SentryNetworkTracker *)networkTracker;
#endif // SENTRY_TARGET_REPLAY_SUPPORTED

@end

NS_ASSUME_NONNULL_END
