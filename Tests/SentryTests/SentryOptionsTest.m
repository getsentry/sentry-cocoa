#import "SentryOptions.h"
#import "SentryError.h"
#import "SentrySDK.h"
#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest

- (void)testEmptyDsn
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDsn:@"" didFailWithError:&error];

    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(NO, options.debug);
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
}

- (void)testInvalidDsn
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDsn:@"https://sentry.io"
                                               didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.sampleRate = nil;
    XCTAssertNil(options.sampleRate);
}

- (void)testSampleRateLowerBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.sampleRate = @0.5;

    NSNumber *sampleRateLowerBound = @0;
    options.sampleRate = sampleRateLowerBound;
    XCTAssertEqual(sampleRateLowerBound, options.sampleRate);

    options.sampleRate = @0.5;

    NSNumber *sampleRateTooLow = @-0.01;
    options.sampleRate = sampleRateTooLow;
    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testSampleRateUpperBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.sampleRate = @0.5;

    NSNumber *upperBound = @1;
    options.sampleRate = upperBound;
    XCTAssertEqual(upperBound, options.sampleRate);

    options.sampleRate = @0.5;

    NSNumber *tooHigh = @1.01;
    options.sampleRate = tooHigh;
    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testEmptyConstructorSetsDefaultValues
{
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertNil(options.parsedDsn);
    [self assertDefaultValues:options];
}

- (void)assertDefaultValues:(SentryOptions *)options
{
    XCTAssertEqual(YES, options.enabled);
    XCTAssertEqual(2.0, options.shutdownTimeInterval);
    XCTAssertEqual(NO, options.debug);
    XCTAssertEqual(kSentryLevelDebug, options.diagnosticLevel);
    XCTAssertEqual(options.environment, kSentryDefaultEnvironment);
    XCTAssertNil(options.dist);
    XCTAssertEqual(defaultMaxBreadcrumbs, options.maxBreadcrumbs);
    XCTAssertTrue(options.enableNetworkBreadcrumbs);
    XCTAssertEqual(30, options.maxCacheItems);
    XCTAssertNil(options.beforeSend);
    XCTAssertNil(options.beforeBreadcrumb);
    XCTAssertNil(options.onCrashedLastRun);
    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
    XCTAssertEqual(@1, options.sampleRate);
    XCTAssertEqual(YES, options.enableAutoSessionTracking);
    XCTAssertEqual(YES, options.enableWatchdogTerminationsTracking);
    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
    XCTAssertEqual(YES, options.attachStacktrace);
    XCTAssertEqual(NO, options.stitchAsyncCode);
    XCTAssertEqual(20 * 1024 * 1024, options.maxAttachmentSize);
    XCTAssertEqual(NO, options.sendDefaultPii);
    XCTAssertTrue(options.enableAutoPerformanceTracing);
#if SENTRY_HAS_UIKIT
    XCTAssertTrue(options.enableUIViewControllerTracing);
    XCTAssertFalse(options.attachScreenshot);
    XCTAssertEqual(3.0, options.idleTimeout);
    XCTAssertEqual(options.enableUserInteractionTracing, YES);
    XCTAssertEqual(options.enablePreWarmedAppStartTracing, NO);
    XCTAssertEqual(options.attachViewHierarchy, NO);
#endif
    XCTAssertFalse(options.enableAppHangTracking);
    XCTAssertEqual(options.appHangTimeoutInterval, 2);
    XCTAssertEqual(YES, options.enableNetworkTracking);
    XCTAssertNil(options.tracesSampleRate);
    XCTAssertNil(options.tracesSampler);
    XCTAssertEqualObjects([self getDefaultInAppIncludes], options.inAppIncludes);
    XCTAssertEqual(@[], options.inAppExcludes);
    XCTAssertNil(options.urlSessionDelegate);
    XCTAssertEqual(YES, options.enableSwizzling);
    XCTAssertEqual(YES, options.enableFileIOTracing);
    XCTAssertEqual(YES, options.enableAutoBreadcrumbTracking);

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, *)) {
        XCTAssertEqual(NO, options.enableMetricKit);
    }
#endif

    NSRegularExpression *regexTrace = options.tracePropagationTargets[0];
    XCTAssertTrue([regexTrace.pattern isEqualToString:@".*"]);

    NSRegularExpression *regexRequests = options.failedRequestTargets[0];
    XCTAssertTrue([regexRequests.pattern isEqualToString:@".*"]);

    XCTAssertEqual(NO, options.enableCaptureFailedRequests);

    SentryHttpStatusCodeRange *range = options.failedRequestStatusCodes[0];
    XCTAssertEqual(500, range.min);
    XCTAssertEqual(599, range.max);

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqual(NO, options.enableProfiling);
#    pragma clang diagnostic pop
    XCTAssertNil(options.profilesSampleRate);
    XCTAssertNil(options.profilesSampler);
#endif
}

- (void)testSetValidDsn
{
    NSString *dsnAsString = @"https://username:password@sentry.io/1";
    SentryOptions *options = [[SentryOptions alloc] init];
    options.dsn = dsnAsString;
    options.enabled = NO;

    SentryDsn *dsn = [[SentryDsn alloc] initWithString:dsnAsString didFailWithError:nil];

    XCTAssertEqual(dsnAsString, options.dsn);
    XCTAssertTrue([dsn.url.absoluteString isEqualToString:options.parsedDsn.url.absoluteString]);
    XCTAssertEqual(NO, options.enabled);
}

- (void)testSetNilDsn
{
    SentryOptions *options = [[SentryOptions alloc] init];

    [options setDsn:nil];
    XCTAssertNil(options.dsn);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(YES, options.enabled);
}

- (void)testSetInvalidValidDsn
{
    SentryOptions *options = [[SentryOptions alloc] init];

    [options setDsn:@"https://username:passwordsentry.io/1"];
    XCTAssertNil(options.dsn);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(YES, options.enabled);
}

- (void)testTracesSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = nil;
    XCTAssertNil(options.tracesSampleRate);
}

- (void)testTracesSampleRateLowerBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = @0.5;

    NSNumber *lowerBound = @0;
    options.tracesSampleRate = lowerBound;
    XCTAssertEqual(lowerBound, options.tracesSampleRate);

    options.tracesSampleRate = @0.5;

    NSNumber *tooLow = @-0.01;
    options.tracesSampleRate = tooLow;
    XCTAssertNil(options.tracesSampleRate);
}

- (void)testTracesSampleRateUpperBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = @0.5;

    NSNumber *lowerBound = @1;
    options.tracesSampleRate = lowerBound;
    XCTAssertEqual(lowerBound, options.tracesSampleRate);

    options.tracesSampleRate = @0.5;

    NSNumber *tooLow = @1.01;
    options.tracesSampleRate = tooLow;
    XCTAssertNil(options.tracesSampleRate);
}

- (void)testIsTracingEnabled_NothingSet_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertFalse(options.isTracingEnabled);
}

- (void)testIsTracingEnabled_TracesSampleRateSetToZero_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = @0.00;
    XCTAssertFalse(options.isTracingEnabled);
}

- (void)testIsTracingEnabled_TracesSampleRateSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = @0.01;
    XCTAssertTrue(options.isTracingEnabled);
}

- (void)testIsTracingEnabled_TracesSamplerSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @0.0;
    };
    XCTAssertTrue(options.isTracingEnabled);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
- (void)testProfilesSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = nil;
    XCTAssertNil(options.profilesSampleRate);
}

- (void)testProfilesSampleRateLowerBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.5;

    NSNumber *lowerBound = @0;
    options.profilesSampleRate = lowerBound;
    XCTAssertEqual(lowerBound, options.profilesSampleRate);

    options.profilesSampleRate = @0.5;

    NSNumber *tooLow = @-0.01;
    options.profilesSampleRate = tooLow;
    XCTAssertNil(options.profilesSampleRate);
}

- (void)testProfilesSampleRateUpperBound
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.5;

    NSNumber *lowerBound = @1;
    options.profilesSampleRate = lowerBound;
    XCTAssertEqual(lowerBound, options.profilesSampleRate);

    options.profilesSampleRate = @0.5;

    NSNumber *tooLow = @1.01;
    options.profilesSampleRate = tooLow;
    XCTAssertNil(options.profilesSampleRate);
}

- (void)testIsProfilingEnabled_NothingSet_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertFalse(options.isProfilingEnabled);
}

- (void)testIsProfilingEnabled_ProfilesSampleRateSetToZero_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.00;
    XCTAssertFalse(options.isProfilingEnabled);
}

- (void)testIsProfilingEnabled_ProfilesSampleRateSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.01;
    XCTAssertTrue(options.isProfilingEnabled);
}

- (void)testIsProfilingEnabled_ProfilesSamplerSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @0.0;
    };
    XCTAssertTrue(options.isProfilingEnabled);
}

- (void)testIsProfilingEnabled_EnableProfilingSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    options.enableProfiling = YES;
#    pragma clang diagnostic pop
    XCTAssertTrue(options.isProfilingEnabled);
}
#endif

- (NSArray<NSString *> *)getDefaultInAppIncludes
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
    NSArray<NSString *> *result;
    if (nil == bundleExecutable) {
        result = @[];
    } else {
        result = @[ bundleExecutable ];
    }
    return result;
}

@end
