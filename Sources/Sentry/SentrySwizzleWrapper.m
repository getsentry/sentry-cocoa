#import "SentrySwizzleWrapper.h"
#import "SentrySwizzle.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySwizzleWrapper ()

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, SentrySwizzleSendActionCallback> *swizzleSendActionCallbacks;
#endif

@end

@implementation SentrySwizzleWrapper

- (instancetype)init
{
    if (self = [super init]) {
#if SENTRY_HAS_UIKIT
        self.swizzleSendActionCallbacks = [NSMutableDictionary new];
#endif
    }
    return self;
}

#if SENTRY_HAS_UIKIT
- (void)swizzleSendAction:(SentrySwizzleSendActionCallback)callback forKey:(NSString *)key
{
    // We need to make a copy of the block to avoid ARC of autoreleasing it.
    self.swizzleSendActionCallbacks[key] = [callback copy];

    if (self.swizzleSendActionCallbacks.count != 1) {
        return;
    }

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    __block SentrySwizzleWrapper *_self = self;
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication.class, selector, SentrySWReturnType(BOOL),
        SentrySWArguments(SEL action, id target, id sender, UIEvent * event), SentrySWReplacement({
            [_self sendActionCalled:action event:event];
            return SentrySWCallOriginal(action, target, sender, event);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#    pragma clang diagnostic pop
}

- (void)removeSwizzleSendActionForKey:(NSString *)key
{
    [self.swizzleSendActionCallbacks removeObjectForKey:key];
}

/**
 * For testing.
 */
- (void)sendActionCalled:(SEL)action event:(UIEvent *)event
{
    for (SentrySwizzleSendActionCallback callback in self.swizzleSendActionCallbacks.allValues) {
        callback([NSString stringWithFormat:@"%s", sel_getName(action)], event);
    }
}
#endif

- (void)removeAllCallbacks
{
#if SENTRY_HAS_UIKIT
    [self.swizzleSendActionCallbacks removeAllObjects];
#endif
}
@end

NS_ASSUME_NONNULL_END
