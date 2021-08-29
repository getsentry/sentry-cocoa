#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

@implementation SentryNetworkSwizzling

+ (void)start
{
    [SentryNetworkTracker.sharedInstance enable];
    [self swizzleURLSessionTaskResume];
    [self swizzleURLRequestInit];
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

+ (void)swizzleURLRequestInit
{
    SEL initWithURLCacheTimeoutSelector = NSSelectorFromString(@"initWithURL:cachePolicy:timeoutInterval:");
    SentrySwizzleInstanceMethod(NSURLRequest.class, initWithURLCacheTimeoutSelector, SentrySWReturnType(NSURLRequest *),
        SentrySWArguments(NSURL *url, NSURLRequestCachePolicy cache, NSTimeInterval interval), SentrySWReplacement({
            return [SentryNetworkTracker.sharedInstance initializeUrlRequest:SentrySWCallOriginal(url, cache, interval)];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)initWithURLCacheTimeoutSelector);
}

#pragma clang diagnostic pop
@end
