// swiftlint:disable file_length
@import SentryObjC;
@import XCTest;

@interface SentryObjCOptionsTests : XCTestCase
@end

@implementation SentryObjCOptionsTests

#pragma mark - String? properties

- (void)testDsn_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.dsn = @"https://key@sentry.io/123";

    // -- Assert --
    XCTAssertEqualObjects(options.dsn, @"https://key@sentry.io/123");
}

- (void)testReleaseName_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.releaseName = @"1.0.0";

    // -- Assert --
    XCTAssertEqualObjects(options.releaseName, @"1.0.0");
}

- (void)testDist_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.dist = @"100";

    // -- Assert --
    XCTAssertEqualObjects(options.dist, @"100");
}

- (void)testOrgId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.orgId = @"org-123";

    // -- Assert --
    XCTAssertEqualObjects(options.orgId, @"org-123");
}

#pragma mark - String properties

- (void)testEnvironment_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.environment = @"production";

    // -- Assert --
    XCTAssertEqualObjects(options.environment, @"production");
}

- (void)testCacheDirectoryPath_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.cacheDirectoryPath = @"/tmp/test";

    // -- Assert --
    XCTAssertEqualObjects(options.cacheDirectoryPath, @"/tmp/test");
}

- (void)testSpotlightUrl_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.spotlightUrl = @"http://localhost:8969/stream";

    // -- Assert --
    XCTAssertEqualObjects(options.spotlightUrl, @"http://localhost:8969/stream");
}

#pragma mark - Bool properties

- (void)testDebug_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.debug = YES;

    // -- Assert --
    XCTAssertTrue(options.debug);
}

- (void)testEnabled_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enabled = YES;

    // -- Assert --
    XCTAssertTrue(options.enabled);
}

- (void)testEnableCrashHandler_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableCrashHandler = YES;

    // -- Assert --
    XCTAssertTrue(options.enableCrashHandler);
}

- (void)testEnableNetworkBreadcrumbs_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableNetworkBreadcrumbs = YES;

    // -- Assert --
    XCTAssertTrue(options.enableNetworkBreadcrumbs);
}

- (void)testEnableLogs_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableLogs = YES;

    // -- Assert --
    XCTAssertTrue(options.enableLogs);
}

- (void)testEnableAutoSessionTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableAutoSessionTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableAutoSessionTracking);
}

- (void)testEnableGraphQLOperationTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableGraphQLOperationTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableGraphQLOperationTracking);
}

- (void)testEnableWatchdogTerminationTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableWatchdogTerminationTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableWatchdogTerminationTracking);
}

- (void)testAttachStacktrace_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.attachStacktrace = YES;

    // -- Assert --
    XCTAssertTrue(options.attachStacktrace);
}

- (void)testAttachAllThreads_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.attachAllThreads = YES;

    // -- Assert --
    XCTAssertTrue(options.attachAllThreads);
}

- (void)testSendDefaultPii_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.sendDefaultPii = YES;

    // -- Assert --
    XCTAssertTrue(options.sendDefaultPii);
}

- (void)testEnableAutoPerformanceTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableAutoPerformanceTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableAutoPerformanceTracing);
}

- (void)testEnablePersistingTracesWhenCrashing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enablePersistingTracesWhenCrashing = YES;

    // -- Assert --
    XCTAssertTrue(options.enablePersistingTracesWhenCrashing);
}

- (void)testEnableNetworkTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableNetworkTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableNetworkTracking);
}

- (void)testEnableFileIOTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableFileIOTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableFileIOTracing);
}

- (void)testEnableDataSwizzling_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableDataSwizzling = YES;

    // -- Assert --
    XCTAssertTrue(options.enableDataSwizzling);
}

- (void)testEnableFileManagerSwizzling_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableFileManagerSwizzling = YES;

    // -- Assert --
    XCTAssertTrue(options.enableFileManagerSwizzling);
}

- (void)testEnableSwizzling_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableSwizzling = YES;

    // -- Assert --
    XCTAssertTrue(options.enableSwizzling);
}

- (void)testEnableCoreDataTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableCoreDataTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableCoreDataTracing);
}

- (void)testSendClientReports_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.sendClientReports = YES;

    // -- Assert --
    XCTAssertTrue(options.sendClientReports);
}

- (void)testEnableAppHangTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableAppHangTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableAppHangTracking);
}

- (void)testEnableAutoBreadcrumbTracking_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableAutoBreadcrumbTracking = YES;

    // -- Assert --
    XCTAssertTrue(options.enableAutoBreadcrumbTracking);
}

- (void)testEnablePropagateTraceparent_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enablePropagateTraceparent = YES;

    // -- Assert --
    XCTAssertTrue(options.enablePropagateTraceparent);
}

- (void)testEnableCaptureFailedRequests_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableCaptureFailedRequests = YES;

    // -- Assert --
    XCTAssertTrue(options.enableCaptureFailedRequests);
}

- (void)testEnableTimeToFullDisplayTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableTimeToFullDisplayTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableTimeToFullDisplayTracing);
}

- (void)testSwiftAsyncStacktraces_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.swiftAsyncStacktraces = YES;

    // -- Assert --
    XCTAssertTrue(options.swiftAsyncStacktraces);
}

- (void)testEnableSpotlight_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableSpotlight = YES;

    // -- Assert --
    XCTAssertTrue(options.enableSpotlight);
}

- (void)testStrictTraceContinuation_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.strictTraceContinuation = YES;

    // -- Assert --
    XCTAssertTrue(options.strictTraceContinuation);
}

- (void)testEnableMetrics_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableMetrics = YES;

    // -- Assert --
    XCTAssertTrue(options.enableMetrics);
}

#pragma mark - Numeric properties

- (void)testShutdownTimeInterval_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.shutdownTimeInterval = 3.0;

    // -- Assert --
    XCTAssertEqualWithAccuracy(options.shutdownTimeInterval, 3.0, 0.001);
}

- (void)testMaxBreadcrumbs_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.maxBreadcrumbs = 50;

    // -- Assert --
    XCTAssertEqual(options.maxBreadcrumbs, 50u);
}

- (void)testMaxCacheItems_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.maxCacheItems = 20;

    // -- Assert --
    XCTAssertEqual(options.maxCacheItems, 20u);
}

- (void)testSessionTrackingIntervalMillis_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.sessionTrackingIntervalMillis = 60000;

    // -- Assert --
    XCTAssertEqual(options.sessionTrackingIntervalMillis, 60000u);
}

- (void)testMaxAttachmentSize_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.maxAttachmentSize = 1024;

    // -- Assert --
    XCTAssertEqual(options.maxAttachmentSize, 1024u);
}

- (void)testAppHangTimeoutInterval_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.appHangTimeoutInterval = 5.0;

    // -- Assert --
    XCTAssertEqualWithAccuracy(options.appHangTimeoutInterval, 5.0, 0.001);
}

- (void)testSampleRate_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.sampleRate = @0.5;

    // -- Assert --
    XCTAssertEqualObjects(options.sampleRate, @0.5);
}

- (void)testTracesSampleRate_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.tracesSampleRate = @1.0;

    // -- Assert --
    XCTAssertEqualObjects(options.tracesSampleRate, @1.0);
}

#pragma mark - Enum property

- (void)testDiagnosticLevel_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.diagnosticLevel = SentryObjCLevelWarning;

    // -- Assert --
    XCTAssertEqual(options.diagnosticLevel, SentryObjCLevelWarning);
}

#pragma mark - Read-only properties

- (void)testIsTracingEnabled_whenRead_shouldReturnBool
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    BOOL val = options.isTracingEnabled;

    // -- Assert --
    XCTAssertFalse(val);
}

- (void)testInAppIncludes_whenRead_shouldReturnNonNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    NSArray *val = options.inAppIncludes;

    // -- Assert --
    XCTAssertNotNil(val);
}

#pragma mark - Method

- (void)testAddInAppInclude_whenCalled_shouldAppendToInAppIncludes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    [options addInAppInclude:@"MyApp"];

    // -- Assert --
    XCTAssertTrue([options.inAppIncludes containsObject:@"MyApp"]);
}

#pragma mark - Collection/complex properties

- (void)testSwizzleClassNameExcludes_whenSet_shouldContainValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.swizzleClassNameExcludes = [NSSet setWithObject:@"MyClass"];

    // -- Assert --
    XCTAssertTrue([options.swizzleClassNameExcludes containsObject:@"MyClass"]);
}

- (void)testTracePropagationTargets_whenSet_shouldReturnCorrectCount
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.tracePropagationTargets = @[ @"example.com" ];

    // -- Assert --
    XCTAssertEqual(options.tracePropagationTargets.count, 1u);
}

- (void)testFailedRequestStatusCodes_whenSet_shouldReturnCorrectCount
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    SentryObjCHttpStatusCodeRange *range = [[SentryObjCHttpStatusCodeRange alloc] initWithMin:500
                                                                                          max:599];

    // -- Act --
    options.failedRequestStatusCodes = @[ range ];

    // -- Assert --
    XCTAssertEqual(options.failedRequestStatusCodes.count, 1u);
}

- (void)testFailedRequestTargets_whenSet_shouldReturnCorrectCount
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.failedRequestTargets = @[ @"api.example.com" ];

    // -- Assert --
    XCTAssertEqual(options.failedRequestTargets.count, 1u);
}

#pragma mark - Object properties

- (void)testExperimental_whenRead_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    SentryObjCExperimentalOptions *experimental = options.experimental;

    // -- Assert --
    XCTAssertNotNil(experimental);
}

#pragma mark - Closure properties

- (void)testBeforeSend_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.beforeSend = ^SentryObjCEvent *_Nullable(SentryObjCEvent *event) { return event; };

    // -- Assert --
    XCTAssertNotNil(options.beforeSend);
}

- (void)testBeforeSend_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.beforeSend = ^SentryObjCEvent *_Nullable(SentryObjCEvent *event) { return event; };

    // -- Act --
    options.beforeSend = nil;

    // -- Assert --
    XCTAssertNil(options.beforeSend);
}

- (void)testBeforeSendSpan_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.beforeSendSpan = ^SentryObjCSpan *_Nullable(SentryObjCSpan *span) { return span; };

    // -- Assert --
    XCTAssertNotNil(options.beforeSendSpan);
}

- (void)testBeforeSendSpan_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.beforeSendSpan = ^SentryObjCSpan *_Nullable(SentryObjCSpan *span) { return span; };

    // -- Act --
    options.beforeSendSpan = nil;

    // -- Assert --
    XCTAssertNil(options.beforeSendSpan);
}

- (void)testBeforeBreadcrumb_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.beforeBreadcrumb = ^SentryObjCBreadcrumb *_Nullable(SentryObjCBreadcrumb *breadcrumb)
    {
        return breadcrumb;
    };

    // -- Assert --
    XCTAssertNotNil(options.beforeBreadcrumb);
}

- (void)testBeforeBreadcrumb_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.beforeBreadcrumb = ^SentryObjCBreadcrumb *_Nullable(SentryObjCBreadcrumb *breadcrumb)
    {
        return breadcrumb;
    };

    // -- Act --
    options.beforeBreadcrumb = nil;

    // -- Assert --
    XCTAssertNil(options.beforeBreadcrumb);
}

- (void)testBeforeCaptureScreenshot_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.beforeCaptureScreenshot = ^BOOL(SentryObjCEvent *event) { return YES; };

    // -- Assert --
    XCTAssertNotNil(options.beforeCaptureScreenshot);
}

- (void)testBeforeCaptureScreenshot_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.beforeCaptureScreenshot = ^BOOL(SentryObjCEvent *event) { return YES; };

    // -- Act --
    options.beforeCaptureScreenshot = nil;

    // -- Assert --
    XCTAssertNil(options.beforeCaptureScreenshot);
}

- (void)testBeforeCaptureViewHierarchy_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.beforeCaptureViewHierarchy = ^BOOL(SentryObjCEvent *event) { return YES; };

    // -- Assert --
    XCTAssertNotNil(options.beforeCaptureViewHierarchy);
}

- (void)testBeforeCaptureViewHierarchy_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.beforeCaptureViewHierarchy = ^BOOL(SentryObjCEvent *event) { return YES; };

    // -- Act --
    options.beforeCaptureViewHierarchy = nil;

    // -- Assert --
    XCTAssertNil(options.beforeCaptureViewHierarchy);
}

- (void)testOnCrashedLastRun_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    options.onCrashedLastRun = ^(SentryObjCEvent *event) { };

    // -- Assert --
    XCTAssertNotNil(options.onCrashedLastRun);
#pragma clang diagnostic pop
}

- (void)testOnCrashedLastRun_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    options.onCrashedLastRun = ^(SentryObjCEvent *event) { };

    // -- Act --
    options.onCrashedLastRun = nil;

    // -- Assert --
    XCTAssertNil(options.onCrashedLastRun);
#pragma clang diagnostic pop
}

- (void)testOnLastRunStatusDetermined_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.onLastRunStatusDetermined
        = ^(SentryObjCLastRunStatus status, SentryObjCEvent *_Nullable event) { };

    // -- Assert --
    XCTAssertNotNil(options.onLastRunStatusDetermined);
}

- (void)testOnLastRunStatusDetermined_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.onLastRunStatusDetermined
        = ^(SentryObjCLastRunStatus status, SentryObjCEvent *_Nullable event) { };

    // -- Act --
    options.onLastRunStatusDetermined = nil;

    // -- Assert --
    XCTAssertNil(options.onLastRunStatusDetermined);
}

- (void)testTracesSampler_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.tracesSampler = ^NSNumber *_Nullable(SentryObjCSamplingContext *context)
    {
        return @1.0;
    };

    // -- Assert --
    XCTAssertNotNil(options.tracesSampler);
}

- (void)testTracesSampler_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];
    options.tracesSampler = ^NSNumber *_Nullable(SentryObjCSamplingContext *context)
    {
        return @1.0;
    };

    // -- Act --
    options.tracesSampler = nil;

    // -- Assert --
    XCTAssertNil(options.tracesSampler);
}

- (void)testInitialScope_whenSetBlock_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.initialScope = ^SentryObjCScope *(SentryObjCScope *scope) { return scope; };

    // -- Assert --
    XCTAssertNotNil(options.initialScope);
}

#pragma mark - Weak/optional object properties

- (void)testUrlSessionDelegate_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.urlSessionDelegate = nil;

    // -- Assert --
    XCTAssertNil(options.urlSessionDelegate);
}

- (void)testUrlSession_whenSetNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.urlSession = nil;

    // -- Assert --
    XCTAssertNil(options.urlSession);
}

#pragma mark - Platform-conditional properties

#if !TARGET_OS_WATCH

- (void)testEnableSigtermReporting_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableSigtermReporting = YES;

    // -- Assert --
    XCTAssertTrue(options.enableSigtermReporting);
}

#endif

#if (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION) && SENTRY_OBJC_HAS_UIKIT

- (void)testEnableUIViewControllerTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableUIViewControllerTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableUIViewControllerTracing);
}

- (void)testAttachScreenshot_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.attachScreenshot = YES;

    // -- Assert --
    XCTAssertTrue(options.attachScreenshot);
}

- (void)testAttachViewHierarchy_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.attachViewHierarchy = YES;

    // -- Assert --
    XCTAssertTrue(options.attachViewHierarchy);
}

- (void)testReportAccessibilityIdentifier_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.reportAccessibilityIdentifier = YES;

    // -- Assert --
    XCTAssertTrue(options.reportAccessibilityIdentifier);
}

- (void)testEnableUserInteractionTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableUserInteractionTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enableUserInteractionTracing);
}

- (void)testIdleTimeout_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.idleTimeout = 5.0;

    // -- Assert --
    XCTAssertEqualWithAccuracy(options.idleTimeout, 5.0, 0.001);
}

- (void)testEnablePreWarmedAppStartTracing_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enablePreWarmedAppStartTracing = YES;

    // -- Assert --
    XCTAssertTrue(options.enablePreWarmedAppStartTracing);
}

- (void)testEnableReportNonFullyBlockingAppHangs_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableReportNonFullyBlockingAppHangs = YES;

    // -- Assert --
    XCTAssertTrue(options.enableReportNonFullyBlockingAppHangs);
}

#endif

#if (TARGET_OS_IOS || TARGET_OS_TV) && SENTRY_OBJC_HAS_UIKIT

- (void)testSessionReplay_whenRead_shouldReturnNotNil
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    SentryObjCReplayOptions *replay = options.sessionReplay;

    // -- Assert --
    XCTAssertNotNil(replay);
}

#endif

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

- (void)testEnableMetricKit_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableMetricKit = YES;

    // -- Assert --
    XCTAssertTrue(options.enableMetricKit);
}

- (void)testEnableMetricKitRawPayload_whenSetToYes_shouldReturnYes
{
    // -- Arrange --
    SentryObjCOptions *options = [[SentryObjCOptions alloc] init];

    // -- Act --
    options.enableMetricKitRawPayload = YES;

    // -- Assert --
    XCTAssertTrue(options.enableMetricKitRawPayload);
}

#endif

@end
