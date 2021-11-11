#import "SentryNetworkTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"
#import "SentrySwizzle.h"
#import <objc/runtime.h>

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    // We are aware that the SDK only creates breadcrumbs for HTTP requests if performance is
    // enabled. A proper fix is not straight forward as we need several checks on SentryOptions in
    // SentryNetworkTracker. As we have a problem with KVO, see
    // https://github.com/getsentry/sentry-cocoa/issues/1328, we don't know if we can keep the
    // SentryNetworkTracker (written on 29th of September 2021). Therefore we accept this tradeof
    // for now.

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because isTracingEnabled is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable NetworkTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableNetworkTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable NetworkTracking because enableNetworkTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    [SentryNetworkTracker.sharedInstance enable];
    [SentryNetworkTrackingIntegration swizzleNSURLSessionConfiguration];
    [SentryNetworkTrackingIntegration swizzleURLSessionTask];
}

- (void)uninstall
{
    [SentryNetworkTracker.sharedInstance disable];
}

// SentrySwizzleInstanceMethod declaration shadows a local variable. The swizzling is working
// fine and we accept this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"

+ (void)swizzleURLSessionTask
{
    /**
     * In order to be able to track a network request, we need to know when it starts and when it
     * finishes. NSURLSessionTask has a `resume` method that starts the request, and the only way to
     * know when it finishes is to check the task `state`. Using KVO is not working, so we are
     * swizzling `setState:`. Depending on the iOS version NSURLSessionTask does not implements
     * `setState:` and Apple uses a subclass returned by NSURLSession that implementes `setState:`.
     * We need to discover which class to swizzle.
     */

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
    NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop

    Class classToSwizzle;

    Class currentClass = [localDataTask class];
    SEL setStateSelector = NSSelectorFromString(@"setState:");

    while (class_getInstanceMethod(currentClass, setStateSelector)) {
        Class superClass = [currentClass superclass];
        IMP classResumeIMP
            = method_getImplementation(class_getInstanceMethod(currentClass, setStateSelector));
        IMP superclassResumeIMP
            = method_getImplementation(class_getInstanceMethod(superClass, setStateSelector));
        if (classResumeIMP != superclassResumeIMP) {
            classToSwizzle = currentClass;
            break;
        }
        currentClass = superClass;
    }

    [localDataTask cancel];
    [session finishTasksAndInvalidate];

    if (classToSwizzle == nil) {
        [SentryLog
            logWithMessage:@"SentryNetworkSwizzling: Didn't find a NSURLSessionTask sub class that "
                           @"implements `setState:` not able to track network requests"
                  andLevel:kSentryLevelDebug];
        return;
    }

    SEL resumeSelector = NSSelectorFromString(@"resume");
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

+ (void)swizzleNSURLSessionConfiguration
{
    // The HTTPAdditionalHeaders is only an instance method for NSURLSessionConfiguration on
    // iOS/tvOS 8.x, 14.x, and 15.x. On the other OS versions, it only has a property.
    // Therefore, we need to make sure that NSURLSessionConfiguration has this method to be able to
    // swizzle it. Otherwise, we would crash. Cause we can't swizzle properties currently, we only
    // swizzle when the method is available.
    // See
    // https://developer.limneos.net/index.php?ios=14.4&framework=CFNetwork.framework&header=NSURLSessionConfiguration.h
    // and
    // https://developer.limneos.net/index.php?ios=13.1.3&framework=CFNetwork.framework&header=__NSCFURLSessionConfiguration.h.
    SEL selector = NSSelectorFromString(@"HTTPAdditionalHeaders");
    Class classToSwizzle = NSURLSessionConfiguration.class;
    Method method = class_getInstanceMethod(classToSwizzle, selector);

    if (method == nil) {
        [SentryLog logWithMessage:@"SentryNetworkSwizzling: Didn't find HTTPAdditionalHeaders on "
                                  @"NSURLSessionConfiguration. Won't add Sentry Trace HTTP headers."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (method != nil) {
        SentrySwizzleInstanceMethod(classToSwizzle, selector, SentrySWReturnType(NSDictionary *),
            SentrySWArguments(), SentrySWReplacement({
                return [SentryNetworkTracker.sharedInstance addTraceHeader:SentrySWCallOriginal()];
            }),
            SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
    }
}

#pragma clang diagnostic pop

@end
