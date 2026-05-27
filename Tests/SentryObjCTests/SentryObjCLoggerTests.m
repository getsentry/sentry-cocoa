@import SentryObjC;
@import XCTest;

@interface SentryObjCLoggerTests : XCTestCase
@end

@implementation SentryObjCLoggerTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.enableLogs = YES;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - trace

- (void)testTrace_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger trace:@"trace message"];
}

- (void)testTraceWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger trace:@"trace" attributes:@{ @"key" : @"value" }];
}

#pragma mark - debug

- (void)testDebug_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger debug:@"debug message"];
}

- (void)testDebugWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger debug:@"debug" attributes:@{ @"key" : @"value" }];
}

#pragma mark - info

- (void)testInfo_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger info:@"info message"];
}

- (void)testInfoWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger info:@"info" attributes:@{ @"key" : @"value" }];
}

#pragma mark - warn

- (void)testWarn_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger warn:@"warn message"];
}

- (void)testWarnWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger warn:@"warn" attributes:@{ @"key" : @"value" }];
}

#pragma mark - error

- (void)testError_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger error:@"error message"];
}

- (void)testErrorWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger error:@"error" attributes:@{ @"key" : @"value" }];
}

#pragma mark - fatal

- (void)testFatal_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger fatal:@"fatal message"];
}

- (void)testFatalWithAttributes_shouldNotCrash
{
    // -- Act & Assert (no crash) --
    [SentryObjCSDK.logger fatal:@"fatal" attributes:@{ @"key" : @"value" }];
}

@end
