#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

@implementation SentryNetworkSwizzling

static BOOL enabled = NO;

+ (void)start
{
    enabled = YES;
    [SentryNetworkSwizzling swizzleURLSessionTaskResume];
}

+ (void)stop
{
    enabled = NO;
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTaskResume
{
    SEL selector = NSSelectorFromString(@"resume");
    SentrySwizzleInstanceMethod(NSURLSessionTask.class, selector, SentrySWReturnType(void),
        SentrySWArguments(), SentrySWReplacement({
            [SentryNetworkTracker.sharedInstance urlSessionTaskResume:self];

            SentrySWCallOriginal();
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
}
#pragma clang diagnostic pop
@end
