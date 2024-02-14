#import "SentryLaunchProfiling+Tests.h"
#import "SentryOptions+HybridSDKs.h"
#import "SentryOptions+Private.h"
#import "SentryProfilingConditionals.h"
#import "SentrySDK+Tests.h"
#import "SentryTraceOrigins.h"
#import "SentryTransactionContext.h"
#import <XCTest/XCTest.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@interface SentryAppLaunchProfilingTests : XCTestCase
@end

@implementation SentryAppLaunchProfilingTests

- (void)testLaunchProfileTransactionContext
{
    SentryTransactionContext *actualContext = context(@1);
    XCTAssertEqual(actualContext.nameSource, kSentryTransactionNameSourceCustom);
    XCTAssert([actualContext.origin isEqualToString:SentryTraceOriginAutoAppStartProfile]);
    XCTAssert(actualContext.sampled);
}

#    define SENTRY_OPTION(name, value)                                                             \
        NSStringFromSelector(@selector(name))                                                      \
            : value

- (void)testDefaultOptionsDoNotEnableLaunchProfiling
{
    XCTAssertFalse(shouldProfileNextLaunch([self defaultOptionsWithOverrides:nil]).shouldProfile,
        @"Default options should not enable launch profiling");
}

- (void)testAppLaunchProfilingNotSufficientToEnableLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultOptionsWithOverrides:@{ SENTRY_OPTION(enableAppLaunchProfiling, @YES) }])
            .shouldProfile,
        @"Default options with only launch profiling option set is not sufficient to enable launch "
        @"profiling");
}

- (void)testAppLaunchProfilingAndTracingOptionsNotSufficientToEnableAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultOptionsWithOverrides:@{ SENTRY_OPTION(enableAppLaunchProfiling, @YES),
                                                  SENTRY_OPTION(enableTracing, @YES) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled are not sufficient to "
        @"enable launch profiling");
}

- (void)
    testAppLaunchProfilingAndTracingAndTracesSampleRateOptionsNotSufficientToEnableAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultOptionsWithOverrides:@{ SENTRY_OPTION(enableAppLaunchProfiling, @YES),
                                                  SENTRY_OPTION(enableTracing, @YES),
                                                  SENTRY_OPTION(tracesSampleRate, @1) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled with traces sample rate of "
        @"1 are not sufficient to enable launch profiling");
}

- (void)testMinimumOptionsRequiredToEnableAppLaunchProfiling
{
    XCTAssert(shouldProfileNextLaunch([self defaultLaunchProfilingOptionsWithOverrides:nil])
                  .shouldProfile,
        @"Default options with app launch profiling and tracing enabled and traces and profiles "
        @"sample rates of 1 should enable launch profiling");
}

- (void)testDisablingLaunchProfilingOptionDisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 enableAppLaunchProfiling, @NO) }])
            .shouldProfile,
        @"Default options with tracing enabled, traces and profiles sample rates of 1, but app "
        @"launch profiling disabled should not enable launch profiling");
}

- (void)testDisablingTracingOptionDisablesAppLaunchProfiling
{
    XCTAssertFalse(shouldProfileNextLaunch(
                       [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                            enableTracing, @NO) }])
                       .shouldProfile,
        @"Default options with app launch profiling enabled, traces and profiles sample rates of "
        @"1, but tracing disabled should not enable launch profiling");
}

- (void)testSettingTracesSampleRateTo0DisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 tracesSampleRate, @0) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled, profiles sample rate of "
        @"1, but traces sample rate of 0 should not enable launch profiling");
}

- (void)testSettingProfilesSampleRateTo0DisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 profilesSampleRate, @0) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled, traces sample rate of 1, "
        @"but profiles sample rate of 0 should not enable launch profiling");
}

- (void)testDisablingAutoPerformanceTracingOptionDisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 enableAutoPerformanceTracing,
                                                                 @NO) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled, traces and profiles "
        @"sample rates of 1, but automatic performance tracing disabled should not enable launch "
        @"profiling");
}

#    if SENTRY_HAS_UIKIT
- (void)testDisablingSwizzlingOptionDisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 enableSwizzling, @NO) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled, traces and profiles "
        @"sample rates of 1, but swizzling disabled should not enable launch profiling");
}

- (void)testDisablingUIViewControllerTracingOptionDisablesAppLaunchProfiling
{
    XCTAssertFalse(
        shouldProfileNextLaunch(
            [self defaultLaunchProfilingOptionsWithOverrides:@{ SENTRY_OPTION(
                                                                 enableUIViewControllerTracing,
                                                                 @NO) }])
            .shouldProfile,
        @"Default options with app launch profiling and tracing enabled, traces and profiles "
        @"sample rates of 1, but UIViewController tracing disabled should not enable launch "
        @"profiling");
}
#    endif // SENTRY_HAS_UIKIT

#    pragma mark - Private

- (SentryOptions *)defaultLaunchProfilingOptionsWithOverrides:
    (NSDictionary<NSString *, id> *)overrides
{
    NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary<NSString *, id>
        dictionaryWithDictionary:@{ SENTRY_OPTION(enableAppLaunchProfiling, @YES),
                                     SENTRY_OPTION(enableTracing, @YES),
                                     SENTRY_OPTION(tracesSampleRate, @1),
                                     SENTRY_OPTION(profilesSampleRate, @1) }];
    [options addEntriesFromDictionary:overrides];
    return [self defaultOptionsWithOverrides:options];
}

- (SentryOptions *)defaultOptionsWithOverrides:(nullable NSDictionary<NSString *, id> *)overrides
{
    NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary<NSString *, id>
        dictionaryWithObject:@"https://username:password@sentry.io/1"
                      forKey:@"dsn"];
    [options addEntriesFromDictionary:overrides];
    NSError *error;
    SentryOptions *sentryOptions = [[SentryOptions alloc] initWithDict:options
                                                      didFailWithError:&error];
    XCTAssertNil(error);
    return sentryOptions;
}

#    undef SENTRY_OPTION

@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
