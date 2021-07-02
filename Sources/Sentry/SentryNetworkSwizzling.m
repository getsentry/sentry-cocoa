#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

@implementation SentryNetworkSwizzling

+ (void)start
{
    [SentryNetworkSwizzling swizzleURLSessionTaskResume];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTaskResume
{
    //    SEL selector = NSSelectorFromString(@"resume");
    //    SentrySwizzleInstanceMethod(NSURLSessionTask.class, selector, SentrySWReturnType(void),
    //        SentrySWArguments(), SentrySWReplacement({
    //            [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];
    //            SentrySWCallOriginal();
    //        }),
    //        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}
#pragma clang diagnostic pop
@end
