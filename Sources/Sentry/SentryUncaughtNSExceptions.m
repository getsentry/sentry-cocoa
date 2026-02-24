#import <Foundation/Foundation.h>

#if TARGET_OS_OSX && !SENTRY_NO_UI_FRAMEWORK

#    import "SentryCrash.h"
#    import "SentryInternalDefines.h"
#    import "SentrySwift.h"
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
            [SentryUncaughtNSExceptions capture:exception];
            return SentrySWCallOriginal(exception);
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
}

+ (void)swizzleNSApplicationCrashOnException
{
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
#    if SENTRY_TEST || SENTRY_TEST_CI
#        pragma clang diagnostic ignored "-Wunused-variable"
#    endif
    // AppKit calls _crashOnException: when an exception is caught during CATransaction flush
    // or view layout, bypassing reportException: entirely. Depending on macOS version, AppKit
    // may call the class method +[NSApplication _crashOnException:] or the instance method
    // -[NSApp _crashOnException:], so we swizzle both.
    SEL selector = NSSelectorFromString(@"_crashOnException:");

    SentrySwizzleClassMethod(NSApplication, selector, SentrySWReturnType(void),
        SentrySWArguments(NSException * exception), SentrySWReplacement({
            [SentryUncaughtNSExceptions capture:exception];
#    if !(SENTRY_TEST || SENTRY_TEST_CI)
            return SentrySWCallOriginal(exception);
#    endif
        }));

    SentrySwizzleInstanceMethod(NSApplication, selector, SentrySWReturnType(void),
        SentrySWArguments(NSException * exception), SentrySWReplacement({
            [SentryUncaughtNSExceptions capture:exception];
#    if !(SENTRY_TEST || SENTRY_TEST_CI)
            return SentrySWCallOriginal(exception);
#    endif
        }),
        SentrySwizzleModeOncePerClassAndSuperclasses, (void *)selector);
#    pragma clang diagnostic pop
}

+ (void)capture:(nullable NSException *)exception
{
    SentryCrashSwift *crash = SentryDependencyContainer.sharedInstance.crashReporter;

    if (crash.uncaughtExceptionHandler == nil) {
        return;
    }

    if (exception == nil) {
        return;
    }

    crash.uncaughtExceptionHandler(SENTRY_UNWRAP_NULLABLE(NSException, exception));
}

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
