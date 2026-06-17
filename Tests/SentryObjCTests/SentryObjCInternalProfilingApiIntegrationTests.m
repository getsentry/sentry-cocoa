@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_PROFILING_SUPPORTED

@interface SentryObjCInternalProfilingApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalProfilingApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#    pragma mark - Accessor

- (void)testInternal_profiling_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalProfilingApi *profiling = SentryObjCSDK.internal.profiling;

    // -- Assert --
    XCTAssertNotNil(profiling);
}

#    pragma mark - start

- (void)testStart_shouldReturnNonZero
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];

    // -- Act --
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];

    // -- Assert --
    XCTAssertGreaterThan(startTime, (uint64_t)0);

    // -- Cleanup --
    [SentryObjCSDK.internal.profiling discardFor:traceId];
}

#    pragma mark - collect

- (void)testCollect_afterStart_shouldReturnPayload
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];
    [NSThread sleepForTimeInterval:0.2];

    // -- Act --
    NSDictionary<NSString *, id> *payload =
        [SentryObjCSDK.internal.profiling collectBetween:startTime
                                                     and:startTime + 200000000
                                                     for:traceId];

    // -- Assert --
    XCTAssertNotNil(payload);
    XCTAssertEqualObjects(payload[@"platform"], @"cocoa");
}

- (void)testCollect_shouldContainProfileStructure
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];
    [NSThread sleepForTimeInterval:0.2];

    // -- Act --
    NSDictionary<NSString *, id> *payload =
        [SentryObjCSDK.internal.profiling collectBetween:startTime
                                                     and:startTime + 200000000
                                                     for:traceId];

    // -- Assert --
    XCTAssertNotNil(payload[@"profile_id"]);
    XCTAssertNotNil(payload[@"device"]);
    NSDictionary *profile = payload[@"profile"];
    XCTAssertNotNil(profile[@"thread_metadata"]);
    XCTAssertNotNil(profile[@"samples"]);
    XCTAssertNotNil(profile[@"stacks"]);
    XCTAssertNotNil(profile[@"frames"]);
}

- (void)testCollect_shouldContainTransactionInfo
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];
    [NSThread sleepForTimeInterval:0.2];

    // -- Act --
    NSDictionary<NSString *, id> *payload =
        [SentryObjCSDK.internal.profiling collectBetween:startTime
                                                     and:startTime + 200000000
                                                     for:traceId];

    // -- Assert --
    NSDictionary *transaction = payload[@"transaction"];
    XCTAssertNotNil(transaction);
    XCTAssertGreaterThan([transaction[@"active_thread_id"] longLongValue], (long long)0);
}

- (void)testCollect_withoutStart_shouldReturnNil
{
    // -- Act --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    NSDictionary<NSString *, id> *result =
        [SentryObjCSDK.internal.profiling collectBetween:0 and:1 for:traceId];

    // -- Assert --
    XCTAssertNil(result);
}

#    pragma mark - discard

- (void)testDiscard_afterStart_shouldNotCrash
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];
    XCTAssertGreaterThan(startTime, (uint64_t)0);
    [NSThread sleepForTimeInterval:0.2];

    // -- Act & Assert (no crash) --
    [SentryObjCSDK.internal.profiling discardFor:traceId];
}

- (void)testDiscard_withoutStart_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    [SentryObjCSDK.internal.profiling discardFor:traceId];
}

@end

#endif
