#import "SentryOptions.h"
#import "SentryError.h"
#import "SentryOptionsInternal.h"
#import "SentrySDKInternal.h"
#import "SentrySpan.h"
#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest

- (void)testEmptyDsn
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{} didFailWithError:&error];

    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(NO, options.debug);
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);

    [self assertDsnNil:options andError:error];
}

- (void)testInvalidDsnBoolean
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @YES }
                                                didFailWithError:&error];

    [self assertDsnNil:options andError:error];
}

- (void)assertDsnNil:(SentryOptions *)options andError:(NSError *)error
{
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(NO, options.debug);
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
}

- (void)testInvalidDsn
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(options);
}

- (void)testInvalidDsnWithNoErrorArgument
{
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:nil];
    XCTAssertNil(options);
}

- (void)testRelease
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @"abc" }];
    XCTAssertEqualObjects(options.releaseName, @"abc");
}

- (void)testSetEmptyRelease
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @"" }];
    XCTAssertEqualObjects(options.releaseName, @"");
}

- (void)testSetReleaseToNonString
{
    SentryOptions *options = [self getValidOptions:@{ @"release" : @2 }];
    XCTAssertEqualObjects(options.releaseName, [self buildDefaultReleaseName]);
}

- (void)testNoReleaseSetUsesDefault
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqualObjects(options.releaseName, [self buildDefaultReleaseName]);
}

- (NSString *)buildDefaultReleaseName
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    return [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"],
        infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]];
}

#if TARGET_OS_OSX
- (void)testEnableReportingUncaughtNSExceptions
{
    [self testBooleanField:@"enableUncaughtNSExceptionReporting" defaultValue:NO];
}
#endif // TARGET_OS_OSX

- (void)testEnvironment
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(options.environment, kSentryDefaultEnvironment);

    options = [self getValidOptions:@{ @"environment" : @"xxx" }];
    XCTAssertEqualObjects(options.environment, @"xxx");
}

- (void)testDist
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.dist);

    options = [self getValidOptions:@{ @"dist" : @"hhh" }];
    XCTAssertEqualObjects(options.dist, @"hhh");
}

- (void)testValidDebug
{
    [self testDebugWith:@YES expected:YES];
    [self testDebugWith:@"YES" expected:YES];
    [self testDebugWith:@(YES) expected:YES];
}

- (void)testInvalidDebug
{
    [self testDebugWith:@"Invalid" expected:NO];
    [self testDebugWith:@NO expected:NO];
    [self testDebugWith:@(NO) expected:NO];
}

- (void)testDebugWith:(NSObject *)debugValue expected:(BOOL)expectedDebugValue
{
    NSError *error = nil;
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{
        @"dsn" : @"https://username:password@sentry.io/1",
        @"debug" : debugValue
    }
                                                didFailWithError:&error];

    XCTAssertNil(error);
    XCTAssertEqual(expectedDebugValue, options.debug);
}

- (void)testValidDiagnosticLevel
{
    [self testDiagnosticlevelWith:@"none" expected:kSentryLevelNone];
    [self testDiagnosticlevelWith:@"debug" expected:kSentryLevelDebug];
    [self testDiagnosticlevelWith:@"info" expected:kSentryLevelInfo];
    [self testDiagnosticlevelWith:@"warning" expected:kSentryLevelWarning];
    [self testDiagnosticlevelWith:@"error" expected:kSentryLevelError];
    [self testDiagnosticlevelWith:@"fatal" expected:kSentryLevelFatal];
}

- (void)testInvalidDiagnosticLevel
{
    [self testDiagnosticlevelWith:@"fatala" expected:kSentryLevelDebug];
    [self testDiagnosticlevelWith:@(YES) expected:kSentryLevelDebug];
}

- (void)testDiagnosticlevelWith:(NSObject *)level expected:(SentryLevel)expected
{
    SentryOptions *options = [self getValidOptions:@{ @"diagnosticLevel" : level }];

    XCTAssertEqual(expected, options.diagnosticLevel);
}

- (void)testEnableSigtermReporting
{
    [self testBooleanField:@"enableSigtermReporting" defaultValue:NO];
}

- (void)testValidEnabled
{
    [self testEnabledWith:@YES expected:YES];
    [self testEnabledWith:@"YES" expected:YES];
    [self testEnabledWith:@(YES) expected:YES];
}

- (void)testInvalidEnabled
{
    [self testEnabledWith:@"Invalid" expected:NO];
    [self testEnabledWith:@NO expected:NO];
    [self testEnabledWith:@(NO) expected:NO];
}

- (void)testEnabledWith:(NSObject *)enabledValue expected:(BOOL)expectedValue
{
    SentryOptions *options = [self getValidOptions:@{ @"enabled" : enabledValue }];

    XCTAssertEqual(expectedValue, options.enabled);
}

- (void)testMaxBreadcrumbs
{
    NSNumber *maxBreadcrumbs = @20;

    SentryOptions *options = [self getValidOptions:@{ @"maxBreadcrumbs" : maxBreadcrumbs }];

    XCTAssertEqual([maxBreadcrumbs unsignedIntValue], options.maxBreadcrumbs);
}

- (void)testEnableNetworkBreadcrumbs
{
    [self testBooleanField:@"enableNetworkBreadcrumbs"];
}

- (void)testEnableAutoBreadcrumbTracking
{
    [self testBooleanField:@"enableAutoBreadcrumbTracking"];
}

- (void)testEnableCoreDataTracking
{
    [self testBooleanField:@"enableCoreDataTracing" defaultValue:YES];
}

- (void)testEnableGraphQLOperationTracking
{
    [self testBooleanField:@"enableGraphQLOperationTracking" defaultValue:NO];
}

- (void)testSendClientReports
{
    [self testBooleanField:@"sendClientReports" defaultValue:YES];
}

- (void)testDefaultMaxBreadcrumbs
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual([@100 unsignedIntValue], options.maxBreadcrumbs);
}

- (void)testMaxBreadcrumbsGarbage
{
    SentryOptions *options = [self getValidOptions:@{ @"maxBreadcrumbs" : self }];

    XCTAssertEqual(100, options.maxBreadcrumbs);
}

- (void)testMaxCacheItems
{
    NSNumber *maxCacheItems = @20;

    SentryOptions *options = [self getValidOptions:@{ @"maxCacheItems" : maxCacheItems }];

    XCTAssertEqual([maxCacheItems unsignedIntValue], options.maxCacheItems);
}

- (void)testMaxCacheItemsGarbage
{
    SentryOptions *options = [self getValidOptions:@{ @"maxCacheItems" : self }];

    XCTAssertEqual(30, options.maxCacheItems);
}

- (void)testDefaultMaxCacheItems
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual([@30 unsignedIntValue], options.maxCacheItems);
}

- (void)testCacheDirectoryPath
{
    SentryOptions *options = [self getValidOptions:@{ @"cacheDirectoryPath" : @"abc" }];
    XCTAssertEqualObjects(options.cacheDirectoryPath, @"abc");

    SentryOptions *options2 = [self getValidOptions:@{ @"cacheDirectoryPath" : @"" }];
    XCTAssertEqualObjects(options2.cacheDirectoryPath, @"");

    SentryOptions *options3 = [self getValidOptions:@{ @"cacheDirectoryPath" : @2 }];
    XCTAssertEqualObjects(options3.cacheDirectoryPath, [self getDefaultCacheDirectoryPath]);
}

- (NSString *)getDefaultCacheDirectoryPath
{
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
        .firstObject;
}

- (void)testBeforeSend
{
    SentryBeforeSendEventCallback callback = ^(SentryEvent *event) { return event; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeSend" : callback }];

    XCTAssertEqual(callback, options.beforeSend);
}

- (void)testDefaultBeforeSend
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeSend);
}

- (void)testGarbageBeforeSend_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"beforeSend" : @"fault" }];

    XCTAssertNil(options.beforeSend);
}

- (void)testNSNullBeforeSend_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"beforeSend" : [NSNull null] }];

    XCTAssertFalse([options.beforeSend isEqual:[NSNull null]]);
}

- (void)testBeforeSendSpan
{
    SentryBeforeSendSpanCallback callback = ^(id<SentrySpan> span) { return span; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeSendSpan" : callback }];

    XCTAssertEqual(callback, options.beforeSendSpan);
}

- (void)testDefaultBeforeSendSpan
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeSendSpan);
}

- (void)testBeforeBreadcrumb
{
    SentryBeforeBreadcrumbCallback callback
        = ^(SentryBreadcrumb *breadcrumb) { return breadcrumb; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeBreadcrumb" : callback }];

    XCTAssertEqual(callback, options.beforeBreadcrumb);
}

- (void)testDefaultBeforeBreadcrumb
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeBreadcrumb);
}

- (void)testBeforeCaptureScreenshot
{
    SentryBeforeCaptureScreenshotCallback callback = ^(SentryEvent *event) {
        if (event.level == kSentryLevelFatal) {
            return NO;
        }

        return YES;
    };
    SentryOptions *options = [self getValidOptions:@{ @"beforeCaptureScreenshot" : callback }];

    XCTAssertEqual(callback, options.beforeCaptureScreenshot);
}

- (void)testDefaultBeforeCaptureScreenshot
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeCaptureScreenshot);
}

- (void)testBeforeCaptureViewHierarchy
{
    SentryBeforeCaptureScreenshotCallback callback = ^(SentryEvent *event) {
        if (event.level == kSentryLevelFatal) {
            return NO;
        }

        return YES;
    };
    SentryOptions *options = [self getValidOptions:@{ @"beforeCaptureViewHierarchy" : callback }];

    XCTAssertEqual(callback, options.beforeCaptureViewHierarchy);
}

- (void)testDefaultBeforeCaptureViewHierarchy
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeCaptureViewHierarchy);
}

- (void)testTracePropagationTargets
{
    SentryOptions *options =
        [self getValidOptions:@{ @"tracePropagationTargets" : @[ @"localhost" ] }];

    XCTAssertEqual(options.tracePropagationTargets.count, 1);
    XCTAssertEqual(options.tracePropagationTargets[0], @"localhost");
}

- (void)testTracePropagationTargetsInvalidInstanceDoesntCrash
{
    SentryOptions *options = [self getValidOptions:@{ @"tracePropagationTargets" : @[ @YES ] }];

    XCTAssertEqual(options.tracePropagationTargets.count, 1);
    XCTAssertEqual(options.tracePropagationTargets[0], @YES);
}

- (void)testFailedRequestTargets
{
    SentryOptions *options =
        [self getValidOptions:@{ @"failedRequestTargets" : @[ @"localhost" ] }];

    XCTAssertEqual(options.failedRequestTargets.count, 1);
    XCTAssertEqual(options.failedRequestTargets[0], @"localhost");
}

- (void)testFailedRequestTargetsInvalidInstanceDoesntCrash
{
    SentryOptions *options = [self getValidOptions:@{ @"failedRequestTargets" : @[ @YES ] }];

    XCTAssertEqual(options.failedRequestTargets.count, 1);
    XCTAssertEqual(options.failedRequestTargets[0], @YES);
}

- (void)testEnableCaptureFailedRequests
{
    [self testBooleanField:@"enableCaptureFailedRequests" defaultValue:YES];
}

- (void)testEnableTimeToFullDisplayTracing
{
    [self testBooleanField:@"enableTimeToFullDisplayTracing" defaultValue:NO];
}

- (void)testFailedRequestStatusCodes
{
    SentryHttpStatusCodeRange *httpStatusCodeRange =
        [[SentryHttpStatusCodeRange alloc] initWithMin:400 max:599];
    SentryOptions *options =
        [self getValidOptions:@{ @"failedRequestStatusCodes" : @[ httpStatusCodeRange ] }];

    XCTAssertEqual(options.failedRequestStatusCodes.count, 1);
    XCTAssertEqual(options.failedRequestStatusCodes[0].min, 400);
    XCTAssertEqual(options.failedRequestStatusCodes[0].max, 599);
}

- (void)testGarbageBeforeBreadcrumb_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"beforeBreadcrumb" : @"fault" }];

    XCTAssertEqual(nil, options.beforeBreadcrumb);
}

- (void)testOnCrashedLastRun
{
    __block BOOL onCrashedLastRunCalled = NO;
    SentryOnCrashedLastRunCallback callback = ^(SentryEvent *event) {
        onCrashedLastRunCalled = YES;
        XCTAssertNotNil(event);
    };
    SentryOptions *options = [self getValidOptions:@{ @"onCrashedLastRun" : callback }];

    options.onCrashedLastRun([[SentryEvent alloc] init]);

    XCTAssertEqual(callback, options.onCrashedLastRun);
    XCTAssertTrue(onCrashedLastRunCalled);
}

- (void)testDefaultOnCrashedLastRun
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.onCrashedLastRun);
}

- (void)testGarbageOnCrashedLastRun_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"onCrashedLastRun" : @"fault" }];

    XCTAssertNil(options.onCrashedLastRun);
}

- (void)testIntegrations
{
    NSArray<NSString *> *integrations = @[ @"integration1", @"integration2" ];
    SentryOptions *options = [self getValidOptions:@{ @"integrations" : integrations }];

    [self assertArrayEquals:integrations actual:options.integrations];
}

- (void)testDefaultIntegrations
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
}

#if SENTRY_HAS_UIKIT
- (void)testIntegrationOrder
{
    XCTAssertEqualObjects(SentryOptions.defaultIntegrations.firstObject,
        NSStringFromClass([SentrySessionReplayIntegration class]));
    XCTAssertEqualObjects(
        SentryOptions.defaultIntegrations[1], NSStringFromClass([SentryCrashIntegration class]));
}
#endif

- (void)testSampleRateWithDict
{
    NSNumber *sampleRate = @0.1;
    SentryOptions *options = [self getValidOptions:@{ @"sampleRate" : sampleRate }];
    XCTAssertEqual(sampleRate, options.sampleRate);
}

- (void)testSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.sampleRate = nil;
    XCTAssertEqual(options.sampleRate.doubleValue, 0);
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

- (void)testSampleRateNotSet
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testEnableAutoSessionTracking
{
    [self testBooleanField:@"enableAutoSessionTracking"];
}

- (void)testEnableWatchdogTerminationTracking
{
    [self testBooleanField:@"enableWatchdogTerminationTracking"];
}

- (void)testSessionTrackingIntervalMillis
{
    NSNumber *sessionTracking = @2000;
    SentryOptions *options =
        [self getValidOptions:@{ @"sessionTrackingIntervalMillis" : sessionTracking }];

    XCTAssertEqual([sessionTracking unsignedIntValue], options.sessionTrackingIntervalMillis);
}

- (void)testDefaultSessionTrackingIntervalMillis
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
}

- (void)testAttachStackTrace
{
    [self testBooleanField:@"attachStacktrace"];
}

- (void)testEnableIOTracking
{
    [self testBooleanField:@"enableFileIOTracing" defaultValue:YES];
}

- (void)testEmptyConstructorSetsDefaultValues
{
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertNil(options.parsedDsn);
    [self assertDefaultValues:options];
}

- (void)testNSNull_SetsDefaultValue
{
    SentryOptions *options = [SentryOptionsInternal initWithDict:@{
        @"urlSession" : [NSNull null],
        @"dsn" : [NSNull null],
        @"enabled" : [NSNull null],
        @"debug" : [NSNull null],
        @"diagnosticLevel" : [NSNull null],
        @"release" : [NSNull null],
        @"environment" : [NSNull null],
        @"dist" : [NSNull null],
        @"maxBreadcrumbs" : [NSNull null],
        @"enableNetworkBreadcrumbs" : [NSNull null],
        @"maxCacheItems" : [NSNull null],
        @"cacheDirectoryPath" : [NSNull null],
        @"beforeSend" : [NSNull null],
        @"beforeBreadcrumb" : [NSNull null],
        @"onCrashedLastRun" : [NSNull null],
        @"integrations" : [NSNull null],
        @"sampleRate" : [NSNull null],
        @"enableAutoSessionTracking" : [NSNull null],
        @"enableOutOfMemoryTracking" : [NSNull null],
        @"sessionTrackingIntervalMillis" : [NSNull null],
        @"attachStacktrace" : [NSNull null],
        @"maxAttachmentSize" : [NSNull null],
        @"sendDefaultPii" : [NSNull null],
        @"enableAutoPerformanceTracing" : [NSNull null],
#if SENTRY_HAS_UIKIT
        @"enableUIViewControllerTracing" : [NSNull null],
        @"attachScreenshot" : [NSNull null],
        @"sessionReplay" : [NSNull null],
#endif // SENTRY_HAS_UIKIT
        @"enableAppHangTracking" : [NSNull null],
        @"appHangTimeoutInterval" : [NSNull null],
        @"enableNetworkTracking" : [NSNull null],
        @"enableAutoBreadcrumbTracking" : [NSNull null],
        @"tracesSampleRate" : [NSNull null],
        @"tracesSampler" : [NSNull null],
#if SENTRY_TARGET_PROFILING_SUPPORTED
        @"profilesSampleRate" : [NSNull null],
        @"profilesSampler" : [NSNull null],
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
        @"inAppIncludes" : [NSNull null],
        @"inAppExcludes" : [NSNull null],
        @"urlSessionDelegate" : [NSNull null],
        @"enableSwizzling" : [NSNull null],
        @"swizzleClassNameExcludes" : [NSNull null],
        @"enableIOTracking" : [NSNull null],
        @"sdk" : [NSNull null],
        @"enableCaptureFailedRequests" : [NSNull null],
        @"failedRequestStatusCodes" : [NSNull null],
        @"enableTimeToFullDisplayTracing" : [NSNull null],
        @"enableTracing" : [NSNull null],
        @"swiftAsyncStacktraces" : [NSNull null],
        @"spotlightUrl" : [NSNull null]
    }
                                                didFailWithError:nil];

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

    XCTAssertTrue([[self getDefaultCacheDirectoryPath] isEqualToString:options.cacheDirectoryPath]);
    XCTAssertNil(options.beforeSend);
    XCTAssertNil(options.beforeBreadcrumb);
    XCTAssertNil(options.onCrashedLastRun);
    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
    XCTAssertEqual(@1, options.sampleRate);
    XCTAssertEqual(YES, options.enableAutoSessionTracking);
    XCTAssertEqual(YES, options.enableWatchdogTerminationTracking);
    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
    XCTAssertEqual(YES, options.attachStacktrace);
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
    XCTAssertEqual(options.reportAccessibilityIdentifier, YES);
    XCTAssertEqual(options.sessionReplay.onErrorSampleRate, 0);
    XCTAssertEqual(options.sessionReplay.sessionSampleRate, 0);
#endif // SENTRY_HAS_UIKIT
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertFalse(options.enableTracing);
#pragma clang diagnostic pop
    XCTAssertTrue(options.enableAppHangTracking);
    XCTAssertEqual(options.appHangTimeoutInterval, 2);
    XCTAssertEqual(YES, options.enableNetworkTracking);
    XCTAssertNil(options.tracesSampleRate);
    XCTAssertNil(options.tracesSampler);
    XCTAssertEqualObjects([self getDefaultInAppIncludes], options.inAppIncludes);
    XCTAssertEqual(@[], options.inAppExcludes);
    XCTAssertNil(options.urlSessionDelegate);
    XCTAssertNil(options.urlSession);
    XCTAssertEqual(YES, options.enableSwizzling);
    XCTAssertEqual([NSSet new], options.swizzleClassNameExcludes);
    XCTAssertEqual(YES, options.enableFileIOTracing);
    XCTAssertEqual(YES, options.enableAutoBreadcrumbTracking);
    XCTAssertFalse(options.swiftAsyncStacktraces);

#if SENTRY_HAS_METRIC_KIT
    if (@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *)) {
        XCTAssertEqual(NO, options.enableMetricKit);
        XCTAssertEqual(NO, options.enableMetricKitRawPayload);
    }
#endif // SENTRY_HAS_METRIC_KIT

    NSRegularExpression *regexTrace = options.tracePropagationTargets[0];
    XCTAssertTrue([regexTrace.pattern isEqualToString:@".*"]);

    NSRegularExpression *regexRequests = options.failedRequestTargets[0];
    XCTAssertTrue([regexRequests.pattern isEqualToString:@".*"]);

    XCTAssertEqual(YES, options.enableCaptureFailedRequests);

    SentryHttpStatusCodeRange *range = options.failedRequestStatusCodes[0];
    XCTAssertEqual(500, range.min);
    XCTAssertEqual(599, range.max);

    XCTAssertFalse(options.enableTimeToFullDisplayTracing);

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqual(NO, options.enableProfiling);
    XCTAssertNil(options.profilesSampleRate);
    XCTAssertNil(options.profilesSampler);
#    pragma clang diagnostic pop
    XCTAssertTrue([options isContinuousProfilingEnabled]);
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

    XCTAssertTrue([options.spotlightUrl isEqualToString:@"http://localhost:8969/stream"]);
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

#if TARGET_OS_OSX
- (void)testDsnViaEnvironment
{
    setenv("SENTRY_DSN", "https://username:password@sentry.io/1", 1);
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertEqualObjects(options.dsn, @"https://username:password@sentry.io/1");
    XCTAssertNotNil(options.parsedDsn);
    setenv("SENTRY_DSN", "", 1);
}

- (void)testInvalidDsnViaEnvironment
{
    setenv("SENTRY_DSN", "foo_bar", 1);
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertNil(options.dsn);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(options.enabled, YES);
    setenv("SENTRY_DSN", "", 1);
}
#endif // TARGET_OS_OSX

- (void)testMaxAttachmentSize
{
    NSNumber *maxAttachmentSize = @21;
    SentryOptions *options = [self getValidOptions:@{ @"maxAttachmentSize" : maxAttachmentSize }];

    XCTAssertEqual([maxAttachmentSize unsignedIntValue], options.maxAttachmentSize);
}

- (void)testDefaultMaxAttachmentSize
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(20 * 1024 * 1024, options.maxAttachmentSize);
}

- (void)testSendDefaultPii
{
    [self testBooleanField:@"sendDefaultPii" defaultValue:NO];
}

- (void)testEnableAutoPerformanceTracing
{
    [self testBooleanField:@"enableAutoPerformanceTracing"];
}

- (void)testEnablePerformanceV2
{
    [self testBooleanField:@"enablePerformanceV2" defaultValue:NO];
}

- (void)testEnablePersistingTracesWhenCrashing
{
    [self testBooleanField:@"enablePersistingTracesWhenCrashing" defaultValue:NO];
}

#if SENTRY_HAS_UIKIT
- (void)testEnableUIViewControllerTracing
{
    [self testBooleanField:@"enableUIViewControllerTracing"];
}

- (void)testAttachScreenshot
{
    [self testBooleanField:@"attachScreenshot" defaultValue:NO];
}

- (void)testReportAccessibilityIdentifier
{
    [self testBooleanField:@"reportAccessibilityIdentifier" defaultValue:YES];
}

- (void)testEnableUserInteractionTracing
{
    [self testBooleanField:@"enableUserInteractionTracing" defaultValue:YES];
}

- (void)testEnableFileIOTracing
{
    [self testBooleanField:@"enableFileIOTracing" defaultValue:YES];
}

- (void)testShutdownTimeInterval
{
    NSNumber *shutdownTimeInterval = @2.1;
    SentryOptions *options =
        [self getValidOptions:@{ @"shutdownTimeInterval" : shutdownTimeInterval }];

    XCTAssertEqual([shutdownTimeInterval doubleValue], options.shutdownTimeInterval);
}

- (void)testIdleTimeout
{
    NSNumber *idleTimeout = @2.1;
    SentryOptions *options = [self getValidOptions:@{ @"idleTimeout" : idleTimeout }];

    XCTAssertEqual([idleTimeout doubleValue], options.idleTimeout);
}

- (void)testEnablePreWarmedAppStartTracking
{
    [self testBooleanField:@"enablePreWarmedAppStartTracing" defaultValue:NO];
}

- (void)testSessionReplaySettingsInit
{
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        SentryOptions *options = [self getValidOptions:@{
            @"sessionReplay" : @ { @"sessionSampleRate" : @2, @"errorSampleRate" : @4 }
        }];
        XCTAssertEqual(options.sessionReplay.sessionSampleRate, 2);
        XCTAssertEqual(options.sessionReplay.onErrorSampleRate, 4);
    }
}

- (void)testSessionReplaySettingsDefaults
{
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        SentryOptions *options = [self getValidOptions:@{ @"sessionReplayOptions" : @ {} }];
        XCTAssertEqual(options.sessionReplay.sessionSampleRate, 0);
        XCTAssertEqual(options.sessionReplay.onErrorSampleRate, 0);
    }
}

#endif // SENTRY_HAS_UIKIT

#if SENTRY_HAS_METRIC_KIT

- (void)testEnableMetricKit
{
    if (@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, *)) {
        [self testBooleanField:@"enableMetricKit" defaultValue:NO];
    }
}

- (void)testenableMetricKitRawPayload
{
    if (@available(iOS 14.0, macOS 12.0, macCatalyst 14.0, *)) {
        [self testBooleanField:@"enableMetricKitRawPayload" defaultValue:NO];
    }
}
#endif // SENTRY_HAS_METRIC_KIT

- (void)testEnableAppHangTracking
{
    [self testBooleanField:@"enableAppHangTracking" defaultValue:YES];
}

#if SENTRY_UIKIT_AVAILABLE

- (void)testEnableAppHangTrackingV2
{
    [self testBooleanField:@"enableAppHangTrackingV2" defaultValue:NO];
}

- (void)testEnableReportNonFullyBlockingAppHangs
{
    [self testBooleanField:@"enableReportNonFullyBlockingAppHangs" defaultValue:YES];
}

#endif // SENTRY_UIKIT_AVAILABLE

- (void)testDefaultAppHangsTimeout
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(2, options.appHangTimeoutInterval);
}

- (void)testEnableNetworkTracking
{
    [self testBooleanField:@"enableNetworkTracking"];
}

- (void)testEnableSwizzling
{
    [self testBooleanField:@"enableSwizzling"];
}

- (void)testSwizzleClassNameExcludes
{
    NSSet<NSString *> *expected = [NSSet setWithObjects:@"Sentry", nil];
    NSSet *swizzleClassNameExcludes = [NSSet setWithObjects:@"Sentry", @2, nil];

    SentryOptions *options =
        [self getValidOptions:@{ @"swizzleClassNameExcludes" : swizzleClassNameExcludes }];

    XCTAssertEqualObjects(expected, options.swizzleClassNameExcludes);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testEnableTracing
{
    SentryOptions *options = [self getValidOptions:@{ @"enableTracing" : @YES }];
    XCTAssertTrue(options.enableTracing);
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 1);
}

- (void)testChanging_enableTracing_afterSetting_tracesSampleRate
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = @0.5;
    options.enableTracing = NO;
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0.5);
    options.enableTracing = YES;
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0.5);
}

- (void)testChanging_enableTracing_afterSetting_tracesSampler
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampler
        = ^NSNumber *(SentrySamplingContext *__unused samplingContext) { return @0.1; };
    options.enableTracing = NO;
    XCTAssertNil(options.tracesSampleRate);
    options.enableTracing = FALSE;
    XCTAssertNil(options.tracesSampleRate);
}

- (void)testChanging_tracesSampleRate_afterSetting_enableTracing
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.enableTracing = YES;
    options.tracesSampleRate = @0;
    XCTAssertTrue(options.enableTracing);
    options.tracesSampleRate = @1;
    XCTAssertTrue(options.enableTracing);

    options.enableTracing = NO;
    options.tracesSampleRate = @0.5;
    XCTAssertFalse(options.enableTracing);
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0.5);
}

- (void)testChanging_tracesSampler_afterSetting_enableTracing
{
    SentryTracesSamplerCallback sampler
        = ^(__unused SentrySamplingContext *context) { return @1.0; };

    SentryOptions *options = [[SentryOptions alloc] init];
    options.enableTracing = YES;
    options.tracesSampler = sampler;
    XCTAssertTrue(options.enableTracing);
    options.tracesSampleRate = @0;
    XCTAssertTrue(options.enableTracing);

    options.enableTracing = NO;
    options.tracesSampler = sampler;
    XCTAssertFalse(options.enableTracing);
}

- (void)testTracesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{ @"tracesSampleRate" : @0.1 }];

    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0.1);
    XCTAssertTrue(options.enableTracing);
}
#pragma clang diagnostic pop

- (void)testDefaultTracesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0);
}

- (void)testTracesSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.tracesSampleRate = nil;
    XCTAssertNil(options.tracesSampleRate);
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0);
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
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0);
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
    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0);
}

- (double)tracesSamplerCallback:(NSDictionary *)context
{
    return 0.1;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testTracesSampler
{
    SentryTracesSamplerCallback sampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @1.0;
    };

    SentryOptions *options = [self getValidOptions:@{ @"tracesSampler" : sampler }];

    SentrySamplingContext *context = [[SentrySamplingContext alloc] init];
    XCTAssertEqual(options.tracesSampler(context), @1.0);
    XCTAssertTrue(options.enableTracing);
}
#pragma clang diagnostic pop

- (void)testDefaultTracesSampler
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.tracesSampler);
}

- (void)testGarbageTracesSampler_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"tracesSampler" : @"fault" }];
    XCTAssertNil(options.tracesSampler);
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
- (void)testEnableProfiling
{
    [self testBooleanField:@"enableProfiling" defaultValue:NO];
}

#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testProfilesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{ @"profilesSampleRate" : @0.1 }];
    XCTAssertEqual(options.profilesSampleRate.doubleValue, 0.1);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testDefaultProfilesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.profilesSampleRate);

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertFalse(options.isProfilingEnabled);

    XCTAssertTrue([options isContinuousProfilingEnabled]);
}

- (void)testProfilesSampleRate_SetToNil
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = nil;
    XCTAssertNil(options.profilesSampleRate);

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertFalse(options.isProfilingEnabled);

    XCTAssert([options isContinuousProfilingEnabled]);
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
    XCTAssertEqual(options.profilesSampleRate.doubleValue, 0);

    // setting an invalid sample rate effectively now enables continuous profiling, since it can let
    // the backing variable remain nil
    XCTAssertFalse([options isContinuousProfilingEnabled]);
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
    XCTAssertEqual(options.profilesSampleRate.doubleValue, 0);

    // setting an invalid sample rate effectively now enables continuous profiling, since it can let
    // the backing variable remain nil
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testIsProfilingEnabled_NothingSet_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertFalse(options.isProfilingEnabled);

    XCTAssertNil(options.profilesSampleRate);
    XCTAssertTrue([options isContinuousProfilingEnabled]);
}

- (void)testIsProfilingEnabled_ProfilesSampleRateSetToZero_IsDisabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.00;

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertFalse(options.isProfilingEnabled);

    XCTAssertNotNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testIsProfilingEnabled_ProfilesSampleRateSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampleRate = @0.01;

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertTrue(options.isProfilingEnabled);

    XCTAssertNotNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testIsProfilingEnabled_ProfilesSamplerSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
    options.profilesSampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @0.0;
    };

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertTrue(options.isProfilingEnabled);

    XCTAssertNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testIsProfilingEnabled_EnableProfilingSet_IsEnabled
{
    SentryOptions *options = [[SentryOptions alloc] init];
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    options.enableProfiling = YES;
#    pragma clang diagnostic pop

    // This property now only refers to trace-based profiling, but renaming it would require a major
    // rev
    XCTAssertTrue(options.isProfilingEnabled);

    XCTAssertNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testProfilesSampler
{
    SentryTracesSamplerCallback sampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @1.0;
    };

    SentryOptions *options = [self getValidOptions:@{ @"profilesSampler" : sampler }];

    SentrySamplingContext *context = [[SentrySamplingContext alloc] init];
    XCTAssertEqual(options.profilesSampler(context), @1.0);
    XCTAssertNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

// this is a tricky part of the API, because while a profilesSampleRate of nil enables continuous
// profiling, just having the profilesSampler set at all disables it, even if the sampler function
// would return nil
- (void)testProfilesSamplerReturnsNil_ContinuousProfilingNotEnabled
{
    SentryTracesSamplerCallback sampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        NSNumber *result = nil;
        return result;
    };

    SentryOptions *options = [self getValidOptions:@{ @"profilesSampler" : sampler }];

    SentrySamplingContext *context = [[SentrySamplingContext alloc] init];
    XCTAssertNil(options.profilesSampler(context));
    XCTAssertNil(options.profilesSampleRate);
    XCTAssertFalse([options isContinuousProfilingEnabled]);
}

- (void)testDefaultProfilesSampler
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.profilesSampler);
    XCTAssertTrue([options isContinuousProfilingEnabled]);
}

- (void)testGarbageProfilesSampler_ReturnsNil
{
    SentryOptions *options = [self getValidOptions:@{ @"profilesSampler" : @"fault" }];
    XCTAssertNil(options.profilesSampler);
    XCTAssertTrue([options isContinuousProfilingEnabled]);
}
#    pragma clang diagnostic pop

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)testInAppIncludes
{
    NSArray<NSString *> *expected = @[ @"iOS-Swift", @"BusinessLogic" ];
    NSArray *inAppIncludes = @[ @"iOS-Swift", @"BusinessLogic", @1 ];
    SentryOptions *options = [self getValidOptions:@{ @"inAppIncludes" : inAppIncludes }];

    NSString *bundleExecutable = [self getBundleExecutable];
    if (nil != bundleExecutable) {
        expected = [expected arrayByAddingObject:bundleExecutable];
    }

    [self assertArrayEquals:expected actual:options.inAppIncludes];
}

- (void)testAddInAppIncludes
{
    SentryOptions *options = [self getValidOptions:@{}];
    [options addInAppInclude:@"App"];

    NSArray<NSString *> *expected = @[ @"App" ];
    NSString *bundleExecutable = [self getBundleExecutable];
    if (nil != bundleExecutable) {
        expected = [expected arrayByAddingObject:bundleExecutable];
    }

    [self assertArrayEquals:expected actual:options.inAppIncludes];
}

- (NSString *)getBundleExecutable
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    return infoDict[@"CFBundleExecutable"];
}

- (void)testDefaultInAppIncludes
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqualObjects([self getDefaultInAppIncludes], options.inAppIncludes);
}

- (void)testInAppExcludes
{
    NSArray<NSString *> *expected = @[ @"Sentry" ];
    NSArray *inAppExcludes = @[ @"Sentry", @2 ];

    SentryOptions *options = [self getValidOptions:@{ @"inAppExcludes" : inAppExcludes }];

    XCTAssertEqualObjects(expected, options.inAppExcludes);
}

- (void)testAddInAppExcludes
{
    SentryOptions *options = [self getValidOptions:@{}];
    [options addInAppExclude:@"App"];
    XCTAssertEqualObjects(@[ @"App" ], options.inAppExcludes);
}

- (void)testDefaultInAppExcludes
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqualObjects(@[], options.inAppExcludes);
}

- (void)testDefaultInitialScope
{
    SentryOptions *options = [self getValidOptions:@{}];
    SentryScope *scope = [[SentryScope alloc] init];
    XCTAssertIdentical(scope, options.initialScope(scope));
}

- (void)testInitialScope
{
    SentryScope * (^initialScope)(SentryScope *)
        = ^SentryScope *(SentryScope *scope) { return scope; };
    SentryOptions *options = [self getValidOptions:@{ @"initialScope" : initialScope }];
    XCTAssertIdentical(initialScope, options.initialScope);
}

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testEnableAppLaunchProfilingDefaultValue
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertFalse(options.enableAppLaunchProfiling);
}
#    pragma clang diagnostic pop
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (SentryOptions *)getValidOptions:(NSDictionary<NSString *, id> *)dict
{
    NSError *error = nil;

    NSMutableDictionary<NSString *, id> *options = [[NSMutableDictionary alloc] init];
    options[@"dsn"] = @"https://username:password@sentry.io/1";

    [options addEntriesFromDictionary:dict];

    SentryOptions *sentryOptions = [SentryOptionsInternal initWithDict:options
                                                      didFailWithError:&error];
    XCTAssertNil(error);
    return sentryOptions;
}

- (void)testURLSession
{
    NSURLSession *urlSession = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

    SentryOptions *options = [self getValidOptions:@{ @"urlSession" : urlSession }];

    XCTAssertNotNil(options.urlSession);
}

- (void)testUrlSessionDelegate
{
    id<NSURLSessionDelegate> urlSessionDelegate = [[UrlSessionDelegateSpy alloc] init];

    SentryOptions *options = [self getValidOptions:@{ @"urlSessionDelegate" : urlSessionDelegate }];

    XCTAssertNotNil(options.urlSessionDelegate);
}

- (void)testDefaultSwiftAsyncStacktraces
{
    SentryOptions *options = [[SentryOptions alloc] init];
    XCTAssertFalse(options.swiftAsyncStacktraces);
}

- (void)testInitialSwiftAsyncStacktraces
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertFalse(options.swiftAsyncStacktraces);
}

- (void)testInitialSwiftAsyncStacktracesYes
{
    SentryOptions *options = [self getValidOptions:@{ @"swiftAsyncStacktraces" : @YES }];
    XCTAssertTrue(options.swiftAsyncStacktraces);
}

- (void)testOptionsDebugDescription
{
    NSNumber *_Nullable (^tracesSampler)(void) = ^NSNumber *_Nullable { return nil; };
    SentryOptions *options = [self getValidOptions:@{
        @"tracesSampler" : tracesSampler,
        @"sampleRate" : @0.123,
    }];
    NSString *debugDescription = options.debugDescription;
    XCTAssertNotNil(debugDescription);
    XCTAssert([debugDescription containsString:@"sampleRate: 0.123"]);
    XCTAssert([debugDescription containsString:@"tracesSampler: <__NSGlobalBlock__: "]);
}

- (void)testEnableSpotlight
{
    [self testBooleanField:@"enableSpotlight" defaultValue:NO];
}

- (void)testSpotlightUrl
{
    SentryOptions *options = [self getValidOptions:@{ @"spotlightUrl" : @"http://localhost:1010" }];
    XCTAssertEqualObjects(options.spotlightUrl, @"http://localhost:1010");

    SentryOptions *options2 = [self getValidOptions:@{ @"spotlightUrl" : @"" }];
    XCTAssertEqualObjects(options2.spotlightUrl, @"");

    SentryOptions *options3 = [self getValidOptions:@{ @"spotlightUrl" : @2 }];
    XCTAssertEqualObjects(options3.spotlightUrl, @"http://localhost:8969/stream");
}

#if SENTRY_HAS_UIKIT
- (void)testIsAppHangTrackingV2Disabled_WhenBothOptionsDisabled
{
    SentryOptions *options = [self
        getValidOptions:@{ @"enableAppHangTrackingV2" : @NO, @"appHangTimeoutInterval" : @0 }];
    XCTAssertTrue(options.isAppHangTrackingV2Disabled);
}

- (void)testIsAppHangTrackingV2Disabled_WhenOnlyEnableAppHangTrackingV2Disabled
{
    SentryOptions *options = [self
        getValidOptions:@{ @"enableAppHangTrackingV2" : @NO, @"appHangTimeoutInterval" : @2.0 }];
    XCTAssertTrue(options.isAppHangTrackingV2Disabled);
}

- (void)testIsAppHangTrackingV2Disabled_WhenOnlyAppHangTimeoutIntervalZero
{
    SentryOptions *options = [self
        getValidOptions:@{ @"enableAppHangTrackingV2" : @YES, @"appHangTimeoutInterval" : @0 }];
    XCTAssertTrue(options.isAppHangTrackingV2Disabled);
}

- (void)testIsAppHangTrackingV2Disabled_WhenBothOptionsEnabled
{
    SentryOptions *options = [self
        getValidOptions:@{ @"enableAppHangTrackingV2" : @YES, @"appHangTimeoutInterval" : @2.0 }];
    XCTAssertFalse(options.isAppHangTrackingV2Disabled);
}
#endif // SENTRY_HAS_UIKIT

#pragma mark - Private

- (void)assertArrayEquals:(NSArray<NSString *> *)expected actual:(NSArray<NSString *> *)actual
{
    XCTAssertEqualObjects([expected sortedArrayUsingSelector:@selector(compare:)],
        [actual sortedArrayUsingSelector:@selector(compare:)]);
}

- (void)testBooleanField:(NSString *)property
{
    [self testBooleanField:property defaultValue:YES];
}

- (void)testBooleanField:(NSString *)property defaultValue:(BOOL)defaultValue
{
    // Opposite of default
    SentryOptions *options = [self getValidOptions:@{ property : @(!defaultValue) }];
    XCTAssertEqual(!defaultValue, [self getProperty:property of:options]);

    // Default
    options = [self getValidOptions:@{}];
    XCTAssertEqual(defaultValue, [self getProperty:property of:options]);

    // Garbage
    options = [self getValidOptions:@{ property : @"" }];
    XCTAssertEqual(NO, [self getProperty:property of:options]);
}

- (BOOL)getProperty:(NSString *)property of:(SentryOptions *)options
{
    SEL selector = NSSelectorFromString(property);
    NSAssert(
        [options respondsToSelector:selector], @"Options doesn't have a property '%@'", property);

    NSInvocation *invocation = [NSInvocation
        invocationWithMethodSignature:[[options class]
                                          instanceMethodSignatureForSelector:selector]];
    [invocation setSelector:selector];
    [invocation setTarget:options];
    [invocation invoke];
    BOOL result;
    [invocation getReturnValue:&result];

    return result;
}

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
