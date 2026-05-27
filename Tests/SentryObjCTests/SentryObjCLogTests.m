@import SentryObjC;
@import XCTest;

@interface SentryObjCLogTests : XCTestCase
@end

@implementation SentryObjCLogTests

#pragma mark - Init

- (void)testInitWithLevelAndBody_shouldSetLevelAndBody
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo
                                                         body:@"Something happened"];

    // -- Assert --
    XCTAssertNotNil(log);
    XCTAssertEqual(log.level, SentryObjCLogLevelInfo);
    XCTAssertEqualObjects(log.body, @"Something happened");
}

- (void)testInitWithLevelBodyAndAttributes_shouldSetAll
{
    // -- Arrange --
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithInteger:42];
    NSDictionary<NSString *, SentryObjCAttribute *> *attrs = @{ @"count" : attr };

    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelWarn
                                                         body:@"Warning"
                                                   attributes:attrs];

    // -- Assert --
    XCTAssertNotNil(log);
    XCTAssertEqual(log.level, SentryObjCLogLevelWarn);
    XCTAssertEqualObjects(log.body, @"Warning");
    XCTAssertEqual(log.attributes.count, 1u);
}

#pragma mark - Body

- (void)testBody_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo
                                                         body:@"Original"];

    // -- Act --
    log.body = @"Updated message";

    // -- Assert --
    XCTAssertEqualObjects(log.body, @"Updated message");
}

#pragma mark - Level

- (void)testLevel_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Act --
    log.level = SentryObjCLogLevelError;

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelError);
}

- (void)testLevel_whenTrace_shouldReturnTrace
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelTrace body:@"t"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelTrace);
}

- (void)testLevel_whenDebug_shouldReturnDebug
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelDebug body:@"d"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelDebug);
}

- (void)testLevel_whenInfo_shouldReturnInfo
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"i"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelInfo);
}

- (void)testLevel_whenWarn_shouldReturnWarn
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelWarn body:@"w"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelWarn);
}

- (void)testLevel_whenError_shouldReturnError
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelError body:@"e"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelError);
}

- (void)testLevel_whenFatal_shouldReturnFatal
{
    // -- Act --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelFatal body:@"f"];

    // -- Assert --
    XCTAssertEqual(log.level, SentryObjCLogLevelFatal);
}

#pragma mark - Timestamp

- (void)testTimestamp_whenDefault_shouldNotBeNil
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Assert --
    XCTAssertNotNil(log.timestamp);
}

- (void)testTimestamp_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    NSDate *now = [NSDate date];

    // -- Act --
    log.timestamp = now;

    // -- Assert --
    XCTAssertEqualObjects(log.timestamp, now);
}

#pragma mark - TraceId

- (void)testTraceId_whenDefault_shouldNotBeNil
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Assert --
    XCTAssertNotNil(log.traceId);
}

- (void)testTraceId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    SentryObjCId *newTraceId = [[SentryObjCId alloc] init];

    // -- Act --
    log.traceId = newTraceId;

    // -- Assert --
    XCTAssertEqualObjects(log.traceId.sentryIdString, newTraceId.sentryIdString);
}

#pragma mark - SpanId

- (void)testSpanId_whenDefault_shouldBeAccessible
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Act/Assert --
    (void)log.spanId; // nullable, verify it compiles
}

- (void)testSpanId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    log.spanId = spanId;

    // -- Assert --
    XCTAssertNotNil(log.spanId);
}

- (void)testSpanId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    log.spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    log.spanId = nil;

    // -- Assert --
    XCTAssertNil(log.spanId);
}

#pragma mark - Attributes

- (void)testAttributes_whenDefault_shouldNotBeNil
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Assert --
    XCTAssertNotNil(log.attributes);
}

- (void)testAttributes_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithString:@"value"];

    // -- Act --
    log.attributes = @{ @"key" : attr };

    // -- Assert --
    XCTAssertEqual(log.attributes.count, 1u);
}

#pragma mark - setAttribute:forKey:

- (void)testSetAttribute_whenCalled_shouldAddAttribute
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelTrace
                                                         body:@"trace"];
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithBoolean:YES];

    // -- Act --
    [log setAttribute:attr forKey:@"enabled"];

    // -- Assert --
    XCTAssertNotNil(log.attributes[@"enabled"]);
}

- (void)testSetAttribute_whenNil_shouldRemoveAttribute
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelTrace
                                                         body:@"trace"];
    SentryObjCAttribute *attr = [[SentryObjCAttribute alloc] initWithBoolean:YES];
    [log setAttribute:attr forKey:@"enabled"];

    // -- Act --
    [log setAttribute:nil forKey:@"enabled"];

    // -- Assert --
    XCTAssertNil(log.attributes[@"enabled"]);
}

#pragma mark - SeverityNumber

- (void)testSeverityNumber_whenDefault_shouldBeAccessible
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Act/Assert --
    (void)log.severityNumber; // nullable, verify it compiles
}

- (void)testSeverityNumber_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];

    // -- Act --
    log.severityNumber = @9;

    // -- Assert --
    XCTAssertEqualObjects(log.severityNumber, @9);
}

- (void)testSeverityNumber_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCLog *log = [[SentryObjCLog alloc] initWithLevel:SentryObjCLogLevelInfo body:@"test"];
    log.severityNumber = @9;

    // -- Act --
    log.severityNumber = nil;

    // -- Assert --
    XCTAssertNil(log.severityNumber);
}

@end
