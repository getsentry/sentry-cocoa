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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Trace %@");
}

- (void)testDebugWithFormat_shouldCaptureAtDebugLevel
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Debug %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelDebug);
    XCTAssertEqualObjects(self.capturedLog.body, @"Debug msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Debug %@");
}

- (void)testInfoWithFormat_shouldCaptureAtInfoLevel
{
    // -- Act --
    [SentryObjCSDK.logger infoWithFormat:@"Info %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelInfo);
    XCTAssertEqualObjects(self.capturedLog.body, @"Info msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Info %@");
}

- (void)testWarnWithFormat_shouldCaptureAtWarnLevel
{
    // -- Act --
    [SentryObjCSDK.logger warnWithFormat:@"Warn %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelWarn);
    XCTAssertEqualObjects(self.capturedLog.body, @"Warn msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Warn %@");
}

- (void)testErrorWithFormat_shouldCaptureAtErrorLevel
{
    // -- Act --
    [SentryObjCSDK.logger errorWithFormat:@"Error %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelError);
    XCTAssertEqualObjects(self.capturedLog.body, @"Error msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Error %@");
}

- (void)testFatalWithFormat_shouldCaptureAtFatalLevel
{
    // -- Act --
    [SentryObjCSDK.logger fatalWithFormat:@"Fatal %@", @"msg"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelFatal);
    XCTAssertEqualObjects(self.capturedLog.body, @"Fatal msg");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Fatal %@");
}

#pragma mark - format: body and template

- (void)testDebugWithFormat_withStringAndInt_shouldProduceCorrectBodyAndTemplate
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"User %@ processed %d items", @"John", 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"User John processed 42 items");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.template"].value,
        @"User %@ processed %d items");
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
        @"100%% complete with %d items");
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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %@");
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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"%d %ld %lld");
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
    XCTAssertEqualObjects(self.capturedLog.body, @"42 ff");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.template"].value, @"%u %x");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @255);
}

#pragma mark - format: float specifiers

- (void)testDebugWithFormat_withDoubleSpecifier_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %f", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Value: 3.140000");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %f");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"double");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withPrecision_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Score: %.2f", 95.5];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Score: 95.50");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Score: %.2f");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @95.5);
}

- (void)testDebugWithFormat_withPrecisionRounding_shouldPreserveRealValue
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Score: %.2f", 95.555];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Score: 95.56");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Score: %.2f");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @95.555);
}

#pragma mark - format: string specifiers

- (void)testDebugWithFormat_withCString_shouldExtractStringParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Hello %s", "world"];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Hello world");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Hello %s");
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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Char: %c");
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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Ptr: %p");
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
    XCTAssertEqualObjects(self.capturedLog.body, @"Size: 1024");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Size: %zu");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @1024);
}

#pragma mark - format: dynamic width

- (void)testDebugWithFormat_withDynamicWidth_shouldOnlyCaptureValueParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Val: %*d", 10, 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Val:         42");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Val: %*d");
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
        @"User %@ (id=%ld) scored %.1f%% on %d/%d tests");
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
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Count: %d");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"source"].value, @"test");
}

- (void)testTraceWithAttributesFormat_shouldMergeUserAttributes
{
    // -- Act --
    [SentryObjCSDK.logger traceWithAttributes:@{ @"key" : @"val" } format:@"Msg: %@", @"hello"];

    // -- Assert --
    XCTAssertEqual(self.capturedLog.level, SentryObjCLogLevelTrace);
    XCTAssertEqualObjects(self.capturedLog.body, @"Msg: hello");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Msg: %@");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"key"].value, @"val");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"hello");
}

#pragma mark - format: legacy Apple specifiers

- (void)testDebugWithFormat_withLegacyD_shouldExtractIntParameter
{
    // -- Act --
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat"
    [SentryObjCSDK.logger debugWithFormat:@"Value: %D", 99];
#pragma clang diagnostic pop

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Value: 99");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %D");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @99);
}

- (void)testDebugWithFormat_withLegacyO_shouldExtractUnsignedIntParameter
{
    // -- Act --
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat"
    [SentryObjCSDK.logger debugWithFormat:@"Octal: %O", 255u];
#pragma clang diagnostic pop

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Octal: 377");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Octal: %O");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @255);
}

- (void)testDebugWithFormat_withLegacyU_shouldExtractUnsignedIntParameter
{
    // -- Act --
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat"
    [SentryObjCSDK.logger debugWithFormat:@"Unsigned: %U", 1024u];
#pragma clang diagnostic pop

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Unsigned: 1024");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Unsigned: %U");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @1024);
}

#pragma mark - format: unichar specifiers

- (void)testDebugWithFormat_withUnicharString_shouldExtractStringParameter
{
    // -- Arrange --
    const unichar chars[] = { 'H', 'i', 0 };

    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Greeting: %S", chars];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Greeting: Hi");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Greeting: %S");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"Hi");
}

- (void)testDebugWithFormat_withUnicharChar_shouldExtractStringParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Char: %C", (unichar)0x2603];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Char: %C");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"string");
    XCTAssertNotNil(self.capturedLog.attributes[@"sentry.message.parameter.0"].value);
}

#pragma mark - format: additional integer specifiers

- (void)testDebugWithFormat_withUppercaseHex_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Hex: %X", 255u];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Hex: FF");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Hex: %X");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @255);
}

- (void)testDebugWithFormat_withOctal_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Octal: %o", 8u];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Octal: 10");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Octal: %o");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @8);
}

- (void)testDebugWithFormat_withISpecifier_shouldExtractIntParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %i", 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Value: 42");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %i");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
}

- (void)testDebugWithFormat_withUnsignedLongLong_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Big: %llu", (unsigned long long)999999999999ULL];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Big: 999999999999");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Big: %llu");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @999999999999ULL);
}

- (void)testDebugWithFormat_withPtrdiffT_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Diff: %td", (ptrdiff_t)42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Diff: 42");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Diff: %td");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
}

- (void)testDebugWithFormat_withQuad_shouldExtractLongLongParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Quad: %qd", (long long)123456789LL];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Quad: 123456789");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Quad: %qd");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @123456789LL);
}

- (void)testDebugWithFormat_withShort_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Short: %hd", (short)42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Short: 42");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Short: %hd");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
}

- (void)testDebugWithFormat_withCharAsInt_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Char: %hhd", (char)65];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Char: 65");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Char: %hhd");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @65);
}

#pragma mark - format: intmax_t / uintmax_t specifiers

- (void)testDebugWithFormat_withIntmaxT_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Max: %jd", (intmax_t)9876543210LL];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Max: 9876543210");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Max: %jd");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @9876543210LL);
}

- (void)testDebugWithFormat_withUintmaxT_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"UMax: %ju", (uintmax_t)9876543210ULL];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"UMax: 9876543210");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"UMax: %ju");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @9876543210ULL);
}

#pragma mark - format: additional float specifiers

- (void)testDebugWithFormat_withScientific_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Sci: %e", 1234.5];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Sci: 1.234500e+03");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Sci: %e");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @1234.5);
}

- (void)testDebugWithFormat_withUpperScientific_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Sci: %E", 1234.5];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Sci: 1.234500E+03");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Sci: %E");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @1234.5);
}

- (void)testDebugWithFormat_withShortestFloat_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Val: %g", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Val: 3.14");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Val: %g");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withUpperShortestFloat_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Val: %G", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Val: 3.14");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Val: %G");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withHexFloat_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Hex: %a", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Hex: %a");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withUpperHexFloat_shouldExtractDoubleParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Hex: %A", 3.14];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Hex: %A");
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14);
}

- (void)testDebugWithFormat_withLongDouble_shouldExtractParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"LongD: %Lf", (long double)2.718];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"LongD: %Lf");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].type, @"double");
    XCTAssertNotNil(self.capturedLog.attributes[@"sentry.message.parameter.0"].value);
}

#pragma mark - format: dynamic precision

- (void)testDebugWithFormat_withDynamicPrecision_shouldOnlyCaptureValueParameter
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Val: %.*f", 2, 3.14159];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.body, @"Val: 3.14");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Val: %.*f");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @3.14159);
    XCTAssertNil(self.capturedLog.attributes[@"sentry.message.parameter.1"]);
}

#pragma mark - format: C string edge cases

- (void)testDebugWithFormat_withNilCString_shouldUseNullPlaceholder
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %s", (const char *)NULL];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %s");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"(null)");
}

- (void)testDebugWithFormat_withInvalidUTF8CString_shouldNotSkipParameter
{
    // -- Arrange --
    const char invalidUTF8[] = { 'H', 'i', (char)0xFF, (char)0xFE, '\0' };

    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"%s then %d", invalidUTF8, 42];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"%s then %d");
    XCTAssertNotNil(self.capturedLog.attributes[@"sentry.message.parameter.0"].value);
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.1"].value, @42);
}

#pragma mark - format: nil unichar string

- (void)testDebugWithFormat_withNilUnicharString_shouldUseNullPlaceholder
{
    // -- Act --
    [SentryObjCSDK.logger debugWithFormat:@"Value: %S", (const unichar *)NULL];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Value: %S");
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @"(null)");
}

#pragma mark - format: SDK attributes take precedence over user attributes

- (void)testDebugWithAttributesFormat_whenUserOverridesTemplate_shouldKeepSDKTemplate
{
    // -- Arrange --
    NSDictionary *userAttrs = @{ @"sentry.message.template" : @"user-override" };

    // -- Act --
    [SentryObjCSDK.logger debugWithAttributes:userAttrs format:@"Count: %d", 42];

    // -- Assert --
    XCTAssertEqualObjects(
        self.capturedLog.attributes[@"sentry.message.template"].value, @"Count: %d");
}

- (void)testDebugWithAttributesFormat_whenUserOverridesParameter_shouldKeepSDKParameter
{
    // -- Arrange --
    NSDictionary *userAttrs = @{ @"sentry.message.parameter.0" : @"user-override" };

    // -- Act --
    [SentryObjCSDK.logger debugWithAttributes:userAttrs format:@"Value: %d", 42];

    // -- Assert --
    XCTAssertEqualObjects(self.capturedLog.attributes[@"sentry.message.parameter.0"].value, @42);
}

#pragma mark - format: trailing percent

- (void)testDebugWithFormat_withTrailingPercent_shouldNotCrash
{
    // -- Act --
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat"
    [SentryObjCSDK.logger debugWithFormat:@"Progress: 50%"];
#pragma clang diagnostic pop

    // -- Assert --
    XCTAssertNotNil(self.capturedLog.body);
    XCTAssertNil(self.capturedLog.attributes[@"sentry.message.template"]);
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
