#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import <objc/runtime.h>

#    import "SentryInternalDefines.h"
#    import "SentryNSExceptionCaptureHelper.h"
#    import "SentrySwizzle.h"
#    import "SentryUncaughtNSExceptions.h"
#    import <AppKit/NSApplication.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryUncaughtNSExceptions

+ (void)configureCrashOnExceptions
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSApplicationCrashOnExceptions" : @YES }];
}

+ (void)swizzleNSApplicationReportException
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL selector = NSSelectorFromString(@"reportException:");
    SentrySwizzleInstanceMethod(NSApplication, selector, SentrySWReturnType(void),
        SentrySWArguments(NSException * exception), SentrySWReplacement({
            [SentryNSExceptionCaptureHelper reportException:exception];
            SentrySWCallOriginal(exception);
            [SentryNSExceptionCaptureHelper reportExceptionDidFinish];
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
}

+ (void)swizzleNSApplicationCrashOnException
{
    // SentrySwizzleClassMethod has no built-in deduplication, so guard against repeated SDK starts.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
#    if SENTRY_TEST || SENTRY_TEST_CI
#        pragma clang diagnostic ignored "-Wunused-variable"
#    endif
        // AppKit calls _crashOnException: when an exception is caught during CATransaction flush
        // or view layout, bypassing reportException: entirely. Depending on macOS version, AppKit
        // may call the class method +[NSApplication _crashOnException:] or the instance method
        // -[NSApp _crashOnException:], so we swizzle both.
        //
        // SentryNSExceptionCaptureHelper handles deduplication: when _crashOnException: is
        // called from within reportException: (e.g., when NSApplicationCrashOnExceptions is YES),
        // the exception is only captured once.
        SEL selector = NSSelectorFromString(@"_crashOnException:");

        // _crashOnException: is a private AppKit method that may not exist on all macOS versions.
        // Only swizzle if the method is actually present on the class/instance.
        if (class_getClassMethod([NSApplication class], selector)) {
            SentrySwizzleClassMethod(NSApplication, selector, SentrySWReturnType(void),
                SentrySWArguments(NSException * exception), SentrySWReplacement({
                    [SentryNSExceptionCaptureHelper crashOnException:exception];
#    if SENTRY_TEST || SENTRY_TEST_CI
                    // Don't call the original in tests as it would abort() the process.
                    swizzleInfo.originalCalled = YES;
#    else
                    return SentrySWCallOriginal(exception);
#    endif
                }));
        }

        if (class_getInstanceMethod([NSApplication class], selector)) {
            SentrySwizzleInstanceMethod(NSApplication, selector, SentrySWReturnType(void),
                SentrySWArguments(NSException * exception), SentrySWReplacement({
                    [SentryNSExceptionCaptureHelper crashOnException:exception];
#    if SENTRY_TEST || SENTRY_TEST_CI
                    // Don't call the original in tests as it would abort() the process.
                    swizzleInfo.originalCalled = YES;
#    else
                    return SentrySWCallOriginal(exception);
#    endif
                }),
                SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
        }
#    pragma clang diagnostic pop
    });
}

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
