#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if UIKIT_LINKED
typedef void (^SentrySwizzleSendActionCallback)(
    NSString *actionName, _Nullable id target, _Nullable id sender, UIEvent *_Nullable event);
#endif

/**
 * A wrapper around swizzling for testability and to only swizzle once when multiple implementations
 * need to be called for the same swizzled method.
 */
@interface SentrySwizzleWrapper : NSObject

#if UIKIT_LINKED
- (void)swizzleSendAction:(SentrySwizzleSendActionCallback)callback forKey:(NSString *)key;

- (void)removeSwizzleSendActionForKey:(NSString *)key;

/**
 * For testing purposes.
 */
- (void)removeAllCallbacks;

#endif

@end

NS_ASSUME_NONNULL_END
