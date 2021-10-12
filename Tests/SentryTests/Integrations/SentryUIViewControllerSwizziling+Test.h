#import "SentryUIViewControllerSwizziling.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@interface SentryUIViewControllerSwizziling (Test)

+ (BOOL)shouldSwizzleViewController:(Class)class;

+ (void)swizzleViewControllerSubClass:(Class)class;

+ (void)swizzleSubclassesOf:(Class)parentClass
              dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
               swizzleBlock:(void (^)(Class))block;

@end

#endif

NS_ASSUME_NONNULL_END
