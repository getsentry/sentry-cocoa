#import "SentryUIViewControllerSanitizer.h"

@implementation SentryUIViewControllerSanitizer

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

+ (NSString *)sanitizeViewControllerName:(id)controller
{
    NSString *description = [NSString stringWithFormat:@"%@", controller];

    NSRange searchedRange = NSMakeRange(0, [description length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:description
                                                                 options:0
                                                                   range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[description substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return description;
}

#if SENTRY_HAS_UIKIT
+ (NSDictionary *)fetchInfoAboutViewController:(UIViewController *)controller
{
    NSMutableDictionary *info = @{}.mutableCopy;

    info[@"screen"] =
        [self sanitizeViewControllerName:[NSString stringWithFormat:@"%@", controller]];

    if ([controller.navigationItem.title length] != 0) {
        info[@"title"] = controller.navigationItem.title;
    } else if ([controller.title length] != 0) {
        info[@"title"] = controller.title;
    }

    info[@"beingPresented"] = controller.beingPresented ? @"true" : @"false";

    if (controller.presentingViewController != nil) {
        info[@"presentingViewController"] =
            [self sanitizeViewControllerName:controller.presentingViewController];
    }

    if (controller.parentViewController != nil) {
        info[@"parentViewController"] =
            [self sanitizeViewControllerName:controller.parentViewController];
    }

    if (controller.view.window != nil) {
        info[@"window"] = controller.view.window.description;
        info[@"window_isKeyWindow"] = controller.view.window.isKeyWindow ? @"true" : @"false";
    }

    return info;
}
#endif

@end
