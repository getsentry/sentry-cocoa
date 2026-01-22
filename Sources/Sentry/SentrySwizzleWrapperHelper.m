#import "SentrySwizzleWrapperHelper.h"
#import "SentryNSURLSessionTaskSearch.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySwizzleWrapperHelper

#if SENTRY_HAS_UIKIT
+ (void)swizzle:(void (^)(SEL action, _Nullable id target, _Nullable id sender,
                    UIEvent *_Nullable event))callback;
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    static const void *swizzleSendActionKey = &swizzleSendActionKey;
    SEL selector = NSSelectorFromString(@"sendAction:to:from:forEvent:");
    SentrySwizzleInstanceMethod(UIApplication, selector, SentrySWReturnType(BOOL),
        SentrySWArguments(SEL action, id target, id sender, UIEvent * event), SentrySWReplacement({
            callback(action, target, sender, event);
            return SentrySWCallOriginal(action, target, sender, event);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleSendActionKey);
#    pragma clang diagnostic pop
}

+ (void)swizzleViewDidAppear:(void (^)(UIViewController *viewController))callback
                      forKey:(const void *)key
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL selector = NSSelectorFromString(@"viewDidAppear:");

    SentrySwizzleMode mode = SentrySwizzleModeOncePerClassAndSuperclasses;

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    // some tests need to swizzle multiple times, once for each test case. but since they're in the
    // same process, if they set something other than "always", subsequent swizzles fail. override
    // it here for tests
    mode = SentrySwizzleModeAlways;
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)

    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(BOOL animated), SentrySWReplacement({
            callback(self);
            SentrySWCallOriginal(animated);
        }),
        mode, key);
#    pragma clang diagnostic pop
}
#endif // SENTRY_HAS_UIKIT

+ (void)swizzleURLSessionTask:(SentryNetworkTracker *)networkTracker
{
    NSArray<Class> *classesToSwizzle = [SentryNSURLSessionTaskSearch urlSessionTaskClassesToTrack];

    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
    SEL setStateSelector = NSSelectorFromString(@"setState:");
    SEL resumeSelector = NSSelectorFromString(@"resume");

    for (Class classToSwizzle in classesToSwizzle) {
        SentrySwizzleInstanceMethod(classToSwizzle, resumeSelector, SentrySWReturnType(void),
            SentrySWArguments(), SentrySWReplacement({
                [networkTracker urlSessionTaskResume:self];
                SentrySWCallOriginal();
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)resumeSelector);

        SentrySwizzleInstanceMethod(classToSwizzle, setStateSelector, SentrySWReturnType(void),
            SentrySWArguments(NSURLSessionTaskState state), SentrySWReplacement({
                [networkTracker urlSessionTask:self setState:state];
                SentrySWCallOriginal(state);
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)setStateSelector);
    }
#pragma clang diagnostic pop
}

@end

NS_ASSUME_NONNULL_END
