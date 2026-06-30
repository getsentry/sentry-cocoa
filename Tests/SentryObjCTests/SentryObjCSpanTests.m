@import SentryObjC;
@import XCTest;

@interface SentryObjCSpanTests : XCTestCase
@property (nonatomic, strong) SentryObjCSpan *sut;
@end

@implementation SentryObjCSpanTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.tracesSampleRate = @1.0;
    }];
    self.sut = [SentryObjCSDK startTransactionWithName:@"test-transaction" operation:@"test-op"];
}

- (void)tearDown
{
    [self.sut finish];
    [SentryObjCSDK close];
    self.sut = nil;
    [super tearDown];
}

#pragma mark - Properties

- (void)testTraceId_shouldReturnId
{
    // -- Act --
    SentryObjCId *traceId = self.sut.traceId;

    // -- Assert --
    XCTAssertNotNil(traceId);
}

- (void)testSpanId_shouldReturnId
{
    // -- Act --
    SentryObjCSpanId *spanId = self.sut.spanId;

    // -- Assert --
    XCTAssertNotNil(spanId);
}

- (void)testParentSpanId_whenTopLevel_shouldBeNil
{
    // -- Act --
    SentryObjCSpanId *parentSpanId = self.sut.parentSpanId;

    // -- Assert --
    XCTAssertNil(parentSpanId);
}

- (void)testSampled_shouldReturnDecision
{
    // -- Act --
    SentryObjCSampleDecision sampled = self.sut.sampled;

    // -- Assert (just exercise the property) --
    (void)sampled;
}

- (void)testOperation_whenSet_shouldReturnValue
{
    // -- Act --
    self.sut.operation = @"new-op";

    // -- Assert --
    XCTAssertEqualObjects(self.sut.operation, @"new-op");
}

- (void)testOrigin_whenSet_shouldReturnValue
{
    // -- Act --
    self.sut.origin = @"manual";

    // -- Assert --
    XCTAssertEqualObjects(self.sut.origin, @"manual");
}

- (void)testSpanDescription_whenSet_shouldReturnValue
{
    // -- Act --
    self.sut.spanDescription = @"my description";

    // -- Assert --
    XCTAssertEqualObjects(self.sut.spanDescription, @"my description");
}

- (void)testSpanDescription_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    self.sut.spanDescription = @"my description";

    // -- Act --
    self.sut.spanDescription = nil;

    // -- Assert --
    XCTAssertNil(self.sut.spanDescription);
}

- (void)testStatus_whenSet_shouldReturnValue
{
    // -- Act --
    self.sut.status = SentryObjCSpanStatusOk;

    // -- Assert --
    XCTAssertEqual(self.sut.status, SentryObjCSpanStatusOk);
}

- (void)testTimestamp_whenSet_shouldReturnValue
{
    // -- Arrange --
    NSDate *date = [NSDate date];

    // -- Act --
    self.sut.timestamp = date;

    // -- Assert --
    XCTAssertEqualObjects(self.sut.timestamp, date);
}

- (void)testTimestamp_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    self.sut.timestamp = [NSDate date];

    // -- Act --
    self.sut.timestamp = nil;

    // -- Assert --
    XCTAssertNil(self.sut.timestamp);
}

- (void)testStartTimestamp_shouldNotBeNil
{
    // -- Act --
    NSDate *startTimestamp = self.sut.startTimestamp;

    // -- Assert --
    XCTAssertNotNil(startTimestamp);
}

- (void)testData_shouldReturnDictionary
{
    // -- Act --
    NSDictionary *data = self.sut.data;

    // -- Assert --
    XCTAssertNotNil(data);
}

- (void)testTags_shouldReturnDictionary
{
    // -- Act --
    NSDictionary *tags = self.sut.tags;

    // -- Assert --
    XCTAssertNotNil(tags);
}

- (void)testIsFinished_whenNotFinished_shouldReturnFalse
{
    // -- Act --
    BOOL finished = self.sut.isFinished;

    // -- Assert --
    XCTAssertFalse(finished);
}

#pragma mark - Trace Context

- (void)testTraceContext_shouldNotBeNil
{
    // -- Act --
    SentryObjCTraceContext *traceContext = self.sut.traceContext;

    // -- Assert --
    XCTAssertNotNil(traceContext);
}

- (void)testTraceContext_traceId_shouldNotBeNil
{
    // -- Act --
    SentryObjCId *traceId = self.sut.traceContext.traceId;

    // -- Assert --
    XCTAssertNotNil(traceId);
}

- (void)testTraceContext_publicKey_shouldNotBeNil
{
    // -- Act --
    NSString *publicKey = self.sut.traceContext.publicKey;

    // -- Assert --
    XCTAssertNotNil(publicKey);
}

- (void)testTraceContext_allProperties_shouldNotCrash
{
    // -- Arrange --
    SentryObjCTraceContext *ctx = self.sut.traceContext;

    // -- Act & Assert (no crash; some may be nil) --
    (void)ctx.releaseName;
    (void)ctx.environment;
    (void)ctx.transaction;
    (void)ctx.sampleRate;
    (void)ctx.sampleRand;
    (void)ctx.sampled;
    (void)ctx.replayId;
    (void)ctx.orgId;
}

#pragma mark - Child Spans

- (void)testStartChild_shouldReturnChildSpan
{
    // -- Act --
    SentryObjCSpan *child = [self.sut startChildWithOperation:@"child-op"];

    // -- Assert --
    XCTAssertNotNil(child);
    XCTAssertNotNil(child.parentSpanId);
}

- (void)testStartChildWithDescription_shouldReturnChildSpan
{
    // -- Act --
    SentryObjCSpan *child = [self.sut startChildWithOperation:@"child-op" description:@"desc"];

    // -- Assert --
    XCTAssertNotNil(child);
    XCTAssertNotNil(child.parentSpanId);
}

#pragma mark - Data

- (void)testSetDataValueForKey_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut setDataValue:@"value" forKey:@"key"];
}

- (void)testRemoveDataForKey_shouldNotCrash
{
    // -- Arrange --
    [self.sut setDataValue:@"value" forKey:@"key"];

    // -- Act & Assert (no crash) --
    [self.sut removeDataForKey:@"key"];
}

#pragma mark - Feature Flags

- (void)testAddFeatureFlagWithName_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut addFeatureFlagWithName:@"checkout" result:YES];
}

#pragma mark - Tags

- (void)testSetTagValueForKey_shouldUpdateTags
{
    // -- Act --
    [self.sut setTagValue:@"val" forKey:@"key"];

    // -- Assert --
    XCTAssertEqualObjects(self.sut.tags[@"key"], @"val");
}

- (void)testRemoveTagForKey_shouldRemoveTag
{
    // -- Arrange --
    [self.sut setTagValue:@"val" forKey:@"key"];

    // -- Act --
    [self.sut removeTagForKey:@"key"];

    // -- Assert --
    XCTAssertNil(self.sut.tags[@"key"]);
}

#pragma mark - Measurements

- (void)testSetMeasurement_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [self.sut setMeasurementWithName:@"metric" value:@42];
}

- (void)testSetMeasurementWithUnit_shouldNotCrash
{
    // -- Arrange --
    SentryObjCMeasurementUnit *unit = [[SentryObjCMeasurementUnit alloc] initWithUnit:@"ms"];

    // -- Act & Assert (no crash) --
    [self.sut setMeasurementWithName:@"metric" value:@42 unit:unit];
}

#pragma mark - Finish

- (void)testFinish_shouldMarkAsFinished
{
    // -- Arrange --
    SentryObjCSpan *child = [self.sut startChildWithOperation:@"op"];

    // -- Act --
    [child finish];

    // -- Assert --
    XCTAssertTrue(child.isFinished);
}

- (void)testFinishWithStatus_shouldMarkAsFinished
{
    // -- Arrange --
    SentryObjCSpan *child = [self.sut startChildWithOperation:@"op"];

    // -- Act --
    [child finishWithStatus:SentryObjCSpanStatusOk];

    // -- Assert --
    XCTAssertTrue(child.isFinished);
}

#pragma mark - Trace Header & Baggage

- (void)testToTraceHeader_shouldReturnHeader
{
    // -- Act --
    SentryObjCTraceHeader *header = [self.sut toTraceHeader];

    // -- Assert --
    XCTAssertNotNil(header);
}

- (void)testBaggageHttpHeader_shouldNotCrash
{
    // -- Act & Assert (no crash; may return nil) --
    (void)[self.sut baggageHttpHeader];
}

@end
