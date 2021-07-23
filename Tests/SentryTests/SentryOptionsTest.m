#import "SentryOptions.h"
#import "SentryError.h"
#import "SentrySDK.h"
#import "SentrySdkInfo.h"
#import "SentryTests-Swift.h"
#import <XCTest/XCTest.h>

@interface SentryOptionsTest : XCTestCase

@end

@implementation SentryOptionsTest

- (void)testEmptyDsn
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{} didFailWithError:&error];

    [self assertDsnNil:options andError:error];
}

- (void)testInvalidDsnBoolean
{
    NSError *error = nil;
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @YES }
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
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{ @"dsn" : @"https://sentry.io" }
                                                didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
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

- (void)testEnvironment
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertNil(options.environment);

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
    SentryOptions *options = [[SentryOptions alloc] initWithDict:@{
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

- (void)testBeforeSend
{
    SentryEvent * (^callback)(SentryEvent *event) = ^(SentryEvent *event) { return event; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeSend" : callback }];

    XCTAssertEqual(callback, options.beforeSend);
}

- (void)testDefaultBeforeSend
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeSend);
}

- (void)testBeforeBreadcrumb
{
    SentryBreadcrumb * (^callback)(SentryBreadcrumb *event)
        = ^(SentryBreadcrumb *breadcrumb) { return breadcrumb; };
    SentryOptions *options = [self getValidOptions:@{ @"beforeBreadcrumb" : callback }];

    XCTAssertEqual(callback, options.beforeBreadcrumb);
}

- (void)testDefaultBeforeBreadcrumb
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.beforeBreadcrumb);
}

- (void)testOnCrashedLastRun
{
    __block BOOL onCrashedLastRunCalled = NO;
    void (^callback)(SentryEvent *event) = ^(SentryEvent *event) {
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

- (void)testIntegrations
{
    NSArray<NSString *> *integrations = @[ @"integration1", @"integration2" ];
    SentryOptions *options = [self getValidOptions:@{ @"integrations" : integrations }];

    XCTAssertEqual(integrations, options.integrations);
}

- (void)testDefaultIntegrations
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
}

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

- (void)testSampleRateNotSet
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(@1, options.sampleRate);
}

- (void)testEnableAutoSessionTracking
{
    SentryOptions *options = [self getValidOptions:@{ @"enableAutoSessionTracking" : @YES }];

    XCTAssertEqual(YES, options.enableAutoSessionTracking);
}

- (void)testDefaultEnableAutoSessionTracking
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(YES, options.enableAutoSessionTracking);
}

- (void)testEnableOutOfMemoryTracking
{
    SentryOptions *options = [self getValidOptions:@{ @"enableOutOfMemoryTracking" : @YES }];

    XCTAssertEqual(YES, options.enableOutOfMemoryTracking);
}

- (void)testDefaultOutOfMemoryTracking
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertEqual(YES, options.enableOutOfMemoryTracking);
}

- (void)testSetOutOfMemoryTrackingGargabe
{
    SentryOptions *options = [self getValidOptions:@{ @"enableOutOfMemoryTracking" : @"" }];

    XCTAssertEqual(NO, options.enableOutOfMemoryTracking);
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

- (void)testAttachStackTraceDisabledPerDefault
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(YES, options.attachStacktrace);
}

- (void)testAttachStackTraceDisabled
{
    SentryOptions *options = [self getValidOptions:@{ @"attachStacktrace" : @NO }];
    XCTAssertEqual(NO, options.attachStacktrace);
}

- (void)testInvalidAttachStackTrace
{
    SentryOptions *options = [self getValidOptions:@{ @"attachStacktrace" : @"Invalid" }];
    XCTAssertEqual(NO, options.attachStacktrace);
}

- (void)testStitchAsyncCodeDisabledPerDefault
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertEqual(NO, options.stitchAsyncCode);
}

- (void)testStitchAsyncCodeEnabled
{
    SentryOptions *options = [self getValidOptions:@{ @"stitchAsyncCode" : @YES }];
    XCTAssertEqual(YES, options.stitchAsyncCode);
}

- (void)testInvalidStitchAsyncCode
{
    SentryOptions *options = [self getValidOptions:@{ @"stitchAsyncCode" : @"Invalid" }];
    XCTAssertEqual(NO, options.stitchAsyncCode);
}

- (void)testEmptyConstructorSetsDefaultValues
{
    SentryOptions *options = [[SentryOptions alloc] init];

    XCTAssertEqual(YES, options.enabled);
    XCTAssertEqual(NO, options.debug);
    XCTAssertEqual(kSentryLevelDebug, options.diagnosticLevel);
    XCTAssertNil(options.parsedDsn);
    XCTAssertEqual(defaultMaxBreadcrumbs, options.maxBreadcrumbs);
    XCTAssertEqual(30, options.maxCacheItems);
    XCTAssertTrue([[SentryOptions defaultIntegrations] isEqualToArray:options.integrations],
        @"Default integrations are not set correctly");
    XCTAssertEqual(@1, options.sampleRate);
    XCTAssertEqual(YES, options.enableAutoSessionTracking);
    XCTAssertEqual(YES, options.enableOutOfMemoryTracking);
    XCTAssertEqual([@30000 unsignedIntValue], options.sessionTrackingIntervalMillis);
    XCTAssertEqual(YES, options.attachStacktrace);
    XCTAssertEqual(NO, options.stitchAsyncCode);
    XCTAssertEqual(20 * 1024 * 1024, options.maxAttachmentSize);
    XCTAssertTrue(options.enableAutoPerformanceTracking);
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

- (void)testSdkInfo
{
    SentryOptions *options = [[SentryOptions alloc] init];

    XCTAssertEqual(SentryMeta.sdkName, options.sdkInfo.name);
    XCTAssertEqual(SentryMeta.versionString, options.sdkInfo.version);
}

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
    SentryOptions *options = [self getValidOptions:@{ @"sendDefaultPii" : @YES }];

    XCTAssertTrue(options.sendDefaultPii);
}

- (void)testSendDefaultPiiGarbage
{
    SentryOptions *options = [self getValidOptions:@{ @"sendDefaultPii" : @"no" }];

    XCTAssertFalse(options.sendDefaultPii);
}

- (void)testDefaultSendDefaultPii
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertFalse(options.sendDefaultPii);
}

- (void)testAutomaticallyTrackPerformance
{
    SentryOptions *options = [self getValidOptions:@{}];
    XCTAssertTrue(options.enableAutoPerformanceTracking);
}

- (void)testDontAutomaticallyTrackPerformance
{
    SentryOptions *options = [self getValidOptions:@{ @"enableAutoPerformanceTracking" : @NO }];
    XCTAssertFalse(options.enableAutoPerformanceTracking);
}

- (void)testTracesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{ @"tracesSampleRate" : @0.1 }];

    XCTAssertEqual(options.tracesSampleRate.doubleValue, 0.1);
}

- (void)testDefaultTracesSampleRate
{
    SentryOptions *options = [self getValidOptions:@{}];

    XCTAssertNil(options.tracesSampleRate);
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

- (double)tracesSamplerCallback:(NSDictionary *)context
{
    return 0.1;
}

- (void)testTracesSampler
{
    SentryTracesSamplerCallback sampler = ^(SentrySamplingContext *context) {
        XCTAssertNotNil(context);
        return @1.0;
    };

    SentryOptions *options = [self getValidOptions:@{ @"tracesSampler" : sampler }];

    SentrySamplingContext *context = [[SentrySamplingContext alloc] init];
    XCTAssertEqual(options.tracesSampler(context), @1.0);
}

- (void)testDefaultTracesSampler
{
    SentryOptions *options = [self getValidOptions:@{}];

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

- (void)testInAppIncludes
{
    NSArray<NSString *> *expected = @[ @"iOS-Swift", @"BusinessLogic" ];
    NSArray *inAppIncludes = @[ @"iOS-Swift", @"BusinessLogic", @1 ];
    SentryOptions *options = [self getValidOptions:@{ @"inAppIncludes" : inAppIncludes }];

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
    if (nil != bundleExecutable) {
        expected = [expected arrayByAddingObject:bundleExecutable];
    }
    XCTAssertEqualObjects(expected, options.inAppIncludes);
}

- (void)testAddInAppIncludes
{
    SentryOptions *options = [self getValidOptions:@{}];
    [options addInAppInclude:@"App"];
    XCTAssertEqualObjects(@[ @"App" ], options.inAppIncludes);
}

- (void)testDefaultInAppIncludes
{
    SentryOptions *options = [self getValidOptions:@{}];

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
    NSArray<NSString *> *expected;
    if (nil == bundleExecutable) {
        expected = @[];
    } else {
        expected = @[ bundleExecutable ];
    }
    XCTAssertEqualObjects(expected, options.inAppIncludes);
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

- (SentryOptions *)getValidOptions:(NSDictionary<NSString *, id> *)dict
{
    NSError *error = nil;

    NSMutableDictionary<NSString *, id> *options = [[NSMutableDictionary alloc] init];
    options[@"dsn"] = @"https://username:password@sentry.io/1";

    [options addEntriesFromDictionary:dict];

    SentryOptions *sentryOptions = [[SentryOptions alloc] initWithDict:options
                                                      didFailWithError:&error];
    XCTAssertNil(error);
    return sentryOptions;
}

- (void)testUrlSessionDelegate
{
    id<NSURLSessionDelegate> urlSessionDelegate = [[UrlSessionDelegateSpy alloc] init];

    SentryOptions *options = [self getValidOptions:@{ @"urlSessionDelegate" : urlSessionDelegate }];

    XCTAssertNotNil(options.urlSessionDelegate);
}

@end
