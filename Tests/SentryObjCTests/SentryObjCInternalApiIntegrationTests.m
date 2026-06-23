@import SentryObjC;
@import XCTest;
#include <signal.h>

static NSString *const kTestDSN = @"https://key@sentry.io/123";

@interface SentryObjCInternalApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = kTestDSN;
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - setTrace:spanId:

- (void)testSetTrace_shouldNotCrash
{
    // -- Arrange --
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act & Assert --
    [SentryObjCSDK.internal setTrace:traceId spanId:spanId];
}

- (void)testSetTrace_withSpecificIds_shouldNotCrash
{
    // -- Arrange --
    SentryObjCId *traceId =
        [[SentryObjCId alloc] initWithUUIDString:@"12c2d058d58442709aa2eca08bf20986"];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] initWithValue:@"abcdef1234567890"];

    // -- Act & Assert --
    [SentryObjCSDK.internal setTrace:traceId spanId:spanId];
}

#pragma mark - setLogOutput:

- (void)testSetLogOutput_whenSet_shouldNotCrash
{
    // -- Act --
    [SentryObjCSDK.internal setLogOutput:^(NSString *message) {
        // handler set
    }];

    // -- Cleanup --
    [SentryObjCSDK.internal setLogOutput:nil];
}

- (void)testSetLogOutput_whenNil_shouldNotCrash
{
    // -- Act & Assert --
    [SentryObjCSDK.internal setLogOutput:nil];
}

#pragma mark - ignoreNextSignal:

- (void)testIgnoreNextSignal_shouldNotCrash
{
    // -- Act & Assert --
    [SentryObjCSDK.internal ignoreNextSignal:SIGABRT];
}

#pragma mark - options

- (void)testOptions_shouldReturnOptions
{
    // -- Act --
    SentryObjCOptions *options = SentryObjCSDK.internal.options;

    // -- Assert --
    XCTAssertNotNil(options);
    XCTAssertEqualObjects(options.dsn, kTestDSN);
}

#pragma mark - optionsFromDictionary:error:

- (void)testOptionsFromDictionary_withValidDSN_shouldReturnOptions
{
    // -- Arrange --
    NSDictionary *dict = @{ @"dsn" : kTestDSN };

    // -- Act --
    NSError *error = nil;
    SentryObjCOptions *options = [SentryObjCSDK.internal optionsFromDictionary:dict error:&error];

    // -- Assert --
    XCTAssertNil(error);
    XCTAssertNotNil(options);
}

- (void)testOptionsFromDictionary_withEmptyDictionary_shouldReturnError
{
    // -- Act --
    NSError *error = nil;
    SentryObjCOptions *options = [SentryObjCSDK.internal optionsFromDictionary:@{ } error:&error];

    // -- Assert --
    XCTAssertNil(options);
    XCTAssertNotNil(error);
}

@end
