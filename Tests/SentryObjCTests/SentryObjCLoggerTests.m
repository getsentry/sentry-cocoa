@import SentryObjC;
@import XCTest;

@interface SentryObjCLoggerTests : XCTestCase
@property (nonatomic, strong, nullable) SentryObjCLog *capturedLog;
@end

@implementation SentryObjCLoggerTests

- (void)setUp
{
    [super setUp];
    __weak typeof(self) weakSelf = self;
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.enableLogs = YES;
        options.beforeSendLog = ^SentryObjCLog *(SentryObjCLog *log) {
            weakSelf.capturedLog = log;
            return log;
        };
    }];
}

- (void)tearDown
{
    self.capturedLog = nil;
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - logger accessibility

- (void)testLogger_shouldBeAccessibleFromSDK
{
    // -- Act --
    SentryObjCLogger *logger = SentryObjCSDK.logger;

    // -- Assert --
    XCTAssertNotNil(logger);
}

#pragma mark - plain string methods

- (void)testTrace_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger trace:@"trace message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelTrace);
    XCTAssertEqualObjects(self.capturedLog.body, @"trace message");
}

- (void)testTraceWithAttributes_shouldCaptureAttributes
{
    // -- Act --
    [SentryObjCSDK.logger trace:@"trace" attributes:@{ @"key" : @"value" }];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"key"].value, @"value");
}

- (void)testDebug_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger debug:@"debug message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelDebug);
    XCTAssertEqualObjects(self.capturedLog.body, @"debug message");
}

- (void)testInfo_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger info:@"info message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelInfo);
    XCTAssertEqualObjects(self.capturedLog.body, @"info message");
}

- (void)testWarn_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger warn:@"warn message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelWarn);
    XCTAssertEqualObjects(self.capturedLog.body, @"warn message");
}

- (void)testError_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger error:@"error message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelError);
    XCTAssertEqualObjects(self.capturedLog.body, @"error message");
}

- (void)testFatal_shouldCaptureLog
{
    // -- Act --
    [SentryObjCSDK.logger fatal:@"fatal message"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelFatal);
    XCTAssertEqualObjects(self.capturedLog.body, @"fatal message");
}

- (void)testInfoWithMixedAttributeTypes_shouldPreserveTypes
{
    // -- Arrange --
    NSDictionary *attributes = @{
        @"string_key" : @"string_value",
        @"int_key" : @42,
        @"double_key" : @3.14,
        @"bool_key" : @YES
    };

    // -- Act --
    [SentryObjCSDK.logger info:@"mixed types" attributes:attributes];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"string_key"].type, @"string");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"int_key"].type, @"integer");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"double_key"].type, @"double");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"bool_key"].type, @"boolean");
}

#pragma mark - format: level dispatch

- (void)testTraceWithFormat_shouldCaptureAtTraceLevel
{
    // -- Act --
    [SentryObjCSDK.logger traceWithFormat:@"Trace %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelTrace);
    XCTAssertEqualObjects(self.capturedLog.body, @"Trace msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Trace {0}");
}

- (void)testDebugWithFormat_shouldCaptureAtDebugLevel
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Debug %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelDebug);
    XCTAssertEqualObjects(self.capturedLog.body, @"Debug msg");
}

- (void)testInfoWithFormat_shouldCaptureAtInfoLevel
{
    // -- Act --
    [SentryObjCSDK.logger infoWithFormat:@"Info %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelInfo);
    XCTAssertEqualObjects(self.capturedLog.body, @"Info msg");
}

- (void)testWarnWithFormat_shouldCaptureAtWarnLevel
{
    // -- Act --
    [SentryObjCSDK.logger warnWithFormat:@"Warn %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelWarn);
    XCTAssertEqualObjects(self.capturedLog.body, @"Warn msg");
}

- (void)testErrorWithFormat_shouldCaptureAtErrorLevel
{
    // -- Act --
    [SentryObjCSDK.logger errorWithFormat:@"Error %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelError);
    XCTAssertEqualObjects(self.capturedLog.body, @"Error msg");
}

- (void)testFatalWithFormat_shouldCaptureAtFatalLevel
{
    // -- Act --
    [SentryObjCSDK.logger fatalWithFormat:@"Fatal %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelFatal);
    XCTAssertEqualObjects(self.capturedLog.body, @"Fatal msg");
}

#pragma mark - format: body and template

- (void)testDebugWithFormat_withStringAndInt_shouldProduceCorrectBodyAndTemplate
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"User %@ processed %d items", @"John", 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"User John processed 42 items");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.template"].value,
        @"User {0} processed {1} items");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"John");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"string");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @42);
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.1"].type, @"integer");
}

- (void)testDebugWithFormat_withNoArgs_shouldNotAddTemplateAttributes
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Plain message"];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Plain message");
    XCTAssertNil(self.capturedLog.attributes[@"sentry.message.template"]);
    XCTAssertNil(self.capturedLog.attributes[@"sentry.message.parameter.0"]);
}

- (void)testDebugWithFormat_withLiteralPercent_shouldProduceCorrectTemplate
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"100%% complete with %d items", 5];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"100% complete with 5 items");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.template"].value,
        @"100% complete with {0} items");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @5);
}

- (void)testDebugWithFormat_withNilObject_shouldUseNullPlaceholder
{
    // -- Arrange --
    NSString *nilString = nil;

    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %@", nilString];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Value: (null)");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"(null)");
}

#pragma mark - format: integer specifiers

- (void)testDebugWithFormat_withIntSpecifiers_shouldExtractTypedParameters
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"%d %ld %lld", 42, (long)99, (long long)123456789LL];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"42 99 123456789");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"{0} {1} {2}");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @99);
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.2"].value, @123456789);
}

- (void)testDebugWithFormat_withUnsignedSpecifiers_shouldExtractParameters
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"%u %x", 42u, 255u];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @255);
}

#pragma mark - format: float specifiers

- (void)testDebugWithFormat_withDoubleSpecifier_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %f", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"double");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withPrecision_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Score: %.2f", 95.5];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @95.5);
}

#pragma mark - format: string specifiers

- (void)testDebugWithFormat_withCString_shouldExtractStringParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Hello %s", "world"];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Hello world");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"string");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"world");
}

- (void)testDebugWithFormat_withChar_shouldExtractStringParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Char: %c", 'A'];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Char: A");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"string");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"A");
}

#pragma mark - format: pointer specifier

- (void)testDebugWithFormat_withPointer_shouldExtractStringParameter
{
    // -- Arrange --
    int dummy = 0;

    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Ptr: %p", &dummy];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"string");
    XCTAssertNotNil(self.capturedLog.attributes[@"sentry.message.parameter.0"].value);
}

#pragma mark - format: size_t specifier

- (void)testDebugWithFormat_withSizeT_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Size: %zu", (size_t)1024];

    // -- Assert --
    XCTAssertNotNil(self.capturedLog.attributes[@"sentry.message.parameter.0"]);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @1024);
}

#pragma mark - format: dynamic width

- (void)testDebugWithFormat_withDynamicWidth_shouldOnlyCaptureValueParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Val: %*d", 10, 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertNil(self.capturedLog.attributes[@"sentry.message.parameter.1"]);
}

#pragma mark - format: mixed types

- (void)testDebugWithFormat_withMixedTypes_shouldExtractAllParameters
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"User %@ (id=%ld) scored %.1f%% on %d/%d tests",
        @"Alice", (long)42, 95.5, 19, 20];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"User Alice (id=42) scored 95.5% on 19/20 tests");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.template"].value,
        @"User {0} (id={1}) scored {2}% on {3}/{4} tests");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"Alice");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.2"].value, @95.5);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.3"].value, @19);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.4"].value, @20);
}

#pragma mark - format: WithAttributes variant

- (void)testDebugWithAttributesFormat_shouldMergeUserAttributes
{
    // -- Arrange --
    NSDictionary *userAttrs = @{ @"source" : @"test" };

    // -- Act --
    [SentryObjCSDK.logger debugWithAttributes:userAttrs format:@"Count: %d", 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Count: 42");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Count: {0}");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"source"].value, @"test");
}

- (void)testTraceWithAttributesFormat_shouldMergeUserAttributes
{
    // -- Act --
    [SentryObjCSDK.logger traceWithAttributes:@{ @"key" : @"val" } format:@"Msg: %@", @"hello"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelTrace);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"key"].value, @"val");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"hello");
}

#pragma mark - logs disabled

- (void)testLoggerMethod_whenLogsDisabled_shouldNotCrash
{
    // -- Arrange --
    [SentryObjCSDK close];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.enableLogs = NO;
    }];

    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger info:@"should not crash"];
    [SentryObjCSDK.logger debugWithFormat:@"User %@ count %d", @"test", 5];
    [SentryObjCSDK.logger debugWithAttributes:@{ @"k" : @"v" } format:@"Val: %f", 1.0];
}

@end
