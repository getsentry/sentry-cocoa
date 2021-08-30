#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

@implementation SentryNetworkSwizzling

+ (void)start
{
    [SentryNetworkTracker.sharedInstance enable];
    [self swizzleURLSessionTaskResume];
    [self swizzleNSURLSessionConfiguration];
}

+ (void)stop
{
    [SentryNetworkTracker.sharedInstance disable];
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

+ (void)swizzleNSURLSessionConfiguration
{
    SEL httpAdditionalHeadersSelector = NSSelectorFromString(@"HTTPAdditionalHeaders");
    SentrySwizzleInstanceMethod(NSURLSessionConfiguration.class, httpAdditionalHeadersSelector,
        SentrySWReturnType(NSDictionary *), SentrySWArguments(), SentrySWReplacement({
            return [SentryNetworkTracker.sharedInstance addTraceHeader:SentrySWCallOriginal()];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)httpAdditionalHeadersSelector);
}

#pragma clang diagnostic pop
@end
