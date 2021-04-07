#import "SentryPerformanceTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope.h"
#import "SentrySwizzle.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

@implementation SentryPerformanceTracker

- (void)start
{
    [self swizzleViewDidLoad];
}

- (void)swizzleViewDidLoad
{
#if SENTRY_HAS_UIKIT
    // SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
    // fine and we accept this warning.
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"

    static const void *swizzleViewDidLoadKey = &swizzleViewDidLoadKey;
    SEL selector = NSSelectorFromString(@"viewDidLoad");
    SentrySwizzleInstanceMethod(UIViewController.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            if (nil != [SentrySDK.currentHub getClient]) {
                [SentrySDK startTransactionWithName:[SentryPerformanceTracker
                                                        sanitizeViewControllerName:
                                                            [NSString stringWithFormat:@"%@", self]]
                                          operation:@"app.lifecycle"];
            }
            SentrySWCallOriginal();
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, swizzleViewDidLoadKey);
#    pragma clang diagnostic pop
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryBreadcrumbTracker "
                              @"swizzleViewDidAppear] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

+ (NSRegularExpression *)viewControllerRegex
{
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(NSString *)controller
{
    NSRange searchedRange = NSMakeRange(0, [controller length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:controller
                                                                 options:0
                                                                   range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[controller substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return controller;
}

@end
