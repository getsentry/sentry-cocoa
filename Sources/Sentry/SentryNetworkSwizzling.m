#import "SentryNetworkSwizzling.h"
#import "SentryHttpInterceptor+Private.h"
#import "SentryNetworkTracker.h"
#import "SentrySwizzle.h"

@implementation SentryNetworkSwizzling

+ (void)start
{
    [SentryNetworkTracker.sharedInstance enable];
    [self swizzleURLSessionTaskResume];

    // NSURLProtocol is only used when NSURLSession.shared is used.
    // If a custom NSURLSession with custom configurations is used SentryHTTPProtocol is not called.
    // To solve this we swizzle the NSURLSession session configuration and add SentryHTTPProtocol in
    // the classProtocol list.
    [self swizzleURLSessionWithConfiguration];
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

+ (void)swizzleURLSessionWithConfiguration
{
    SentrySwizzleClassMethod(NSURLSession.class,
        NSSelectorFromString(@"sessionWithConfiguration:delegate:delegateQueue:"),
        SentrySWReturnType(NSURLSession *),
        SentrySWArguments(NSURLSessionConfiguration * configuration,
            id<NSURLSessionDelegate> delegate, NSOperationQueue * queue),
        SentrySWReplacement({
            [SentryHttpInterceptor configureSessionConfiguration:configuration];
            return SentrySWCallOriginal(configuration, delegate, queue);
        }));
}

#pragma clang diagnostic pop
@end
