@import SentryObjC;
@import XCTest;

#if SENTRY_OBJC_PROFILING_SUPPORTED

@interface SentryObjCInternalProfilingApiTests : XCTestCase
@end

@implementation SentryObjCInternalProfilingApiTests

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

#    pragma mark - start

- (void)testStart_shouldReturnNonZero
{
    // -- Act --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    uint64_t startTime = [SentryObjCSDK.internal.profiling startFor:traceId];

    // -- Assert --
    XCTAssertGreaterThan(startTime, (uint64_t)0);

    // -- Cleanup --
    [SentryObjCSDK.internal.profiling discardFor:traceId];
}

#    pragma mark - collect

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

- (void)testDiscard_withoutStart_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    [SentryObjCSDK.internal.profiling discardFor:traceId];
}

@end

#endif
