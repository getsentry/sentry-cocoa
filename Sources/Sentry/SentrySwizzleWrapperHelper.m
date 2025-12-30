#import "SentrySwizzleWrapperHelper.h"
#import "SentryNSURLSessionTaskSearch.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySwizzleWrapperHelper

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

+ (void)swizzleURLSessionTask
{
    NSArray<Class> *classesToSwizzle = [SentryNSURLSessionTaskSearch urlSessionTaskClassesToTrack];

    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL setStateSelector = NSSelectorFromString(@"setState:");
    SEL resumeSelector = NSSelectorFromString(@"resume");

    for (Class classToSwizzle in classesToSwizzle) {
        SentrySwizzleInstanceMethod(classToSwizzle, resumeSelector, SentrySWReturnType(void),
            SentrySWArguments(), SentrySWReplacement({
                [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];
                SentrySWCallOriginal();
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)resumeSelector);

        SentrySwizzleInstanceMethod(classToSwizzle, setStateSelector, SentrySWReturnType(void),
            SentrySWArguments(NSURLSessionTaskState state), SentrySWReplacement({
                [SentryNetworkTracker.sharedInstance urlSessionTask:self setState:state];
                SentrySWCallOriginal(state);
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)setStateSelector);
    }
#    pragma clang diagnostic pop
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
