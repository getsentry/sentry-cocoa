#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCEventTests : XCTestCase
@end

@implementation SentryObjCEventTests

- (void)testInit_whenDefault_shouldHaveEventIdAndPlatform
{
    // -- Act --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Assert --
    XCTAssertGreaterThan(event.eventId.sentryIdString.length, 0u);
    XCTAssertEqualObjects(event.platform, @"cocoa");
}

- (void)testInitWithLevel_whenError_shouldSetLevel
{
    // -- Act --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] initWithLevel:SentryObjCLevelError];

    // -- Assert --
    XCTAssertEqual(event.level, SentryObjCLevelError);
}

- (void)testInitWithError_whenProvided_shouldSetError
{
    // -- Arrange --
    NSError *nsError = [NSError errorWithDomain:@"test" code:42 userInfo:nil];

    // -- Act --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] initWithError:nsError];

    // -- Assert --
    XCTAssertEqualObjects(event.error.domain, @"test");
    XCTAssertEqual(event.error.code, 42);
}

- (void)testEventId_whenDefault_shouldBeNonEmptyString
{
    // -- Act --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Assert --
    XCTAssertGreaterThan(event.eventId.sentryIdString.length, 0u);
}

- (void)testEventId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCId *newId = [[SentryObjCId alloc] init];

    // -- Act --
    event.eventId = newId;

    // -- Assert --
    XCTAssertEqualObjects(event.eventId.sentryIdString, newId.sentryIdString);
}

- (void)testMessage_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCMessage *msg = [[SentryObjCMessage alloc] initWithFormatted:@"hello"];

    // -- Act --
    event.message = msg;

    // -- Assert --
    XCTAssertEqualObjects(event.message.formatted, @"hello");
}

- (void)testMessage_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.message = [[SentryObjCMessage alloc] initWithFormatted:@"hello"];

    // -- Act --
    event.message = nil;

    // -- Assert --
    XCTAssertNil(event.message);
}

- (void)testError_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    NSError *nsError = [NSError errorWithDomain:@"test" code:42 userInfo:nil];

    // -- Act --
    event.error = nsError;

    // -- Assert --
    XCTAssertEqualObjects(event.error.domain, @"test");
    XCTAssertEqual(event.error.code, 42);
}

- (void)testError_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.error = [NSError errorWithDomain:@"test" code:42 userInfo:nil];

    // -- Act --
    event.error = nil;

    // -- Assert --
    XCTAssertNil(event.error);
}

- (void)testTimestamp_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    NSDate *now = [NSDate date];

    // -- Act --
    event.timestamp = now;

    // -- Assert --
    XCTAssertEqualObjects(event.timestamp, now);
}

- (void)testTimestamp_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.timestamp = [NSDate date];

    // -- Act --
    event.timestamp = nil;

    // -- Assert --
    XCTAssertNil(event.timestamp);
}

- (void)testStartTimestamp_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    NSDate *now = [NSDate date];

    // -- Act --
    event.startTimestamp = now;

    // -- Assert --
    XCTAssertEqualObjects(event.startTimestamp, now);
}

- (void)testStartTimestamp_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.startTimestamp = [NSDate date];

    // -- Act --
    event.startTimestamp = nil;

    // -- Assert --
    XCTAssertNil(event.startTimestamp);
}

- (void)testLevel_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.level = SentryObjCLevelWarning;

    // -- Assert --
    XCTAssertEqual(event.level, SentryObjCLevelWarning);
}

- (void)testPlatform_whenDefault_shouldBeCocoa
{
    // -- Act --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Assert --
    XCTAssertEqualObjects(event.platform, @"cocoa");
}

- (void)testPlatform_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.platform = @"cocoa";

    // -- Assert --
    XCTAssertEqualObjects(event.platform, @"cocoa");
}

- (void)testLogger_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.logger = @"my.logger";

    // -- Assert --
    XCTAssertEqualObjects(event.logger, @"my.logger");
}

- (void)testLogger_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.logger = @"my.logger";

    // -- Act --
    event.logger = nil;

    // -- Assert --
    XCTAssertNil(event.logger);
}

- (void)testServerName_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.serverName = @"server01";

    // -- Assert --
    XCTAssertEqualObjects(event.serverName, @"server01");
}

- (void)testServerName_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.serverName = @"server01";

    // -- Act --
    event.serverName = nil;

    // -- Assert --
    XCTAssertNil(event.serverName);
}

- (void)testReleaseName_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.releaseName = @"1.0.0";

    // -- Assert --
    XCTAssertEqualObjects(event.releaseName, @"1.0.0");
}

- (void)testReleaseName_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.releaseName = @"1.0.0";

    // -- Act --
    event.releaseName = nil;

    // -- Assert --
    XCTAssertNil(event.releaseName);
}

- (void)testDist_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.dist = @"100";

    // -- Assert --
    XCTAssertEqualObjects(event.dist, @"100");
}

- (void)testDist_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.dist = @"100";

    // -- Act --
    event.dist = nil;

    // -- Assert --
    XCTAssertNil(event.dist);
}

- (void)testEnvironment_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.environment = @"production";

    // -- Assert --
    XCTAssertEqualObjects(event.environment, @"production");
}

- (void)testEnvironment_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.environment = @"production";

    // -- Act --
    event.environment = nil;

    // -- Assert --
    XCTAssertNil(event.environment);
}

- (void)testTransaction_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.transaction = @"GET /api";

    // -- Assert --
    XCTAssertEqualObjects(event.transaction, @"GET /api");
}

- (void)testTransaction_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.transaction = @"GET /api";

    // -- Act --
    event.transaction = nil;

    // -- Assert --
    XCTAssertNil(event.transaction);
}

- (void)testType_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.type = @"transaction";

    // -- Assert --
    XCTAssertEqualObjects(event.type, @"transaction");
}

- (void)testType_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.type = @"transaction";

    // -- Act --
    event.type = nil;

    // -- Assert --
    XCTAssertNil(event.type);
}

- (void)testTags_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.tags = @{ @"env" : @"prod" };

    // -- Assert --
    XCTAssertEqualObjects(event.tags[@"env"], @"prod");
}

- (void)testTags_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.tags = @{ @"env" : @"prod" };

    // -- Act --
    event.tags = nil;

    // -- Assert --
    XCTAssertNil(event.tags);
}

- (void)testExtra_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.extra = @{ @"info" : @"detail" };

    // -- Assert --
    XCTAssertEqualObjects(event.extra[@"info"], @"detail");
}

- (void)testExtra_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.extra = @{ @"info" : @"detail" };

    // -- Act --
    event.extra = nil;

    // -- Assert --
    XCTAssertNil(event.extra);
}

- (void)testSdk_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.sdk = @{ @"name" : @"sentry.cocoa" };

    // -- Assert --
    XCTAssertEqualObjects(event.sdk[@"name"], @"sentry.cocoa");
}

- (void)testSdk_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.sdk = @{ @"name" : @"sentry.cocoa" };

    // -- Act --
    event.sdk = nil;

    // -- Assert --
    XCTAssertNil(event.sdk);
}

- (void)testModules_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.modules = @{ @"MyModule" : @"1.0" };

    // -- Assert --
    XCTAssertEqualObjects(event.modules[@"MyModule"], @"1.0");
}

- (void)testModules_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.modules = @{ @"MyModule" : @"1.0" };

    // -- Act --
    event.modules = nil;

    // -- Assert --
    XCTAssertNil(event.modules);
}

- (void)testFingerprint_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    event.fingerprint = @[ @"custom-fingerprint" ];

    // -- Assert --
    XCTAssertEqualObjects(event.fingerprint, (@[ @"custom-fingerprint" ]));
}

- (void)testFingerprint_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.fingerprint = @[ @"custom-fingerprint" ];

    // -- Act --
    event.fingerprint = nil;

    // -- Assert --
    XCTAssertNil(event.fingerprint);
}

- (void)testUser_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCUser *user = [[SentryObjCUser alloc] initWithUserId:@"u1"];

    // -- Act --
    event.user = user;

    // -- Assert --
    XCTAssertEqualObjects(event.user.userId, @"u1");
}

- (void)testUser_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.user = [[SentryObjCUser alloc] initWithUserId:@"u1"];

    // -- Act --
    event.user = nil;

    // -- Assert --
    XCTAssertNil(event.user);
}

- (void)testContext_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    NSDictionary *context = @{ @"device" : @ { @"name" : @"iPhone" } };

    // -- Act --
    event.context = context;

    // -- Assert --
    XCTAssertEqualObjects(event.context[@"device"][@"name"], @"iPhone");
}

- (void)testContext_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.context = @{ @"device" : @ { @"name" : @"iPhone" } };

    // -- Act --
    event.context = nil;

    // -- Assert --
    XCTAssertNil(event.context);
}

- (void)testThreads_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@(1)];

    // -- Act --
    event.threads = @[ thread ];

    // -- Assert --
    XCTAssertEqual(event.threads.count, 1u);
    XCTAssertEqualObjects(event.threads[0].threadId, @(1));
}

- (void)testThreads_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.threads = @[ [[SentryObjCThread alloc] initWithThreadId:@(1)] ];

    // -- Act --
    event.threads = nil;

    // -- Assert --
    XCTAssertNil(event.threads);
}

- (void)testExceptions_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCException *exc = [[SentryObjCException alloc] initWithValue:@"bad" type:@"Error"];

    // -- Act --
    event.exceptions = @[ exc ];

    // -- Assert --
    XCTAssertEqual(event.exceptions.count, 1u);
    XCTAssertEqualObjects(event.exceptions[0].value, @"bad");
    XCTAssertEqualObjects(event.exceptions[0].type, @"Error");
}

- (void)testExceptions_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.exceptions = @[ [[SentryObjCException alloc] initWithValue:@"bad" type:@"Error"] ];

    // -- Act --
    event.exceptions = nil;

    // -- Assert --
    XCTAssertNil(event.exceptions);
}

- (void)testStacktrace_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ }];

    // -- Act --
    event.stacktrace = st;

    // -- Assert --
    XCTAssertEqual(event.stacktrace.frames.count, 0u);
}

- (void)testStacktrace_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.stacktrace = [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ }];

    // -- Act --
    event.stacktrace = nil;

    // -- Assert --
    XCTAssertNil(event.stacktrace);
}

- (void)testDebugMeta_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCDebugMeta *dm = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    event.debugMeta = @[ dm ];

    // -- Assert --
    XCTAssertEqual(event.debugMeta.count, 1u);
}

- (void)testDebugMeta_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.debugMeta = @[ [[SentryObjCDebugMeta alloc] init] ];

    // -- Act --
    event.debugMeta = nil;

    // -- Assert --
    XCTAssertNil(event.debugMeta);
}

- (void)testBreadcrumbs_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"nav"];

    // -- Act --
    event.breadcrumbs = @[ crumb ];

    // -- Assert --
    XCTAssertEqual(event.breadcrumbs.count, 1u);
    XCTAssertEqualObjects(event.breadcrumbs[0].category, @"nav");
}

- (void)testBreadcrumbs_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"nav"];
    event.breadcrumbs = @[ crumb ];

    // -- Act --
    event.breadcrumbs = nil;

    // -- Assert --
    XCTAssertNil(event.breadcrumbs);
}

- (void)testRequest_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCRequest *req = [[SentryObjCRequest alloc] init];
    req.url = @"https://example.com";

    // -- Act --
    event.request = req;

    // -- Assert --
    XCTAssertEqualObjects(event.request.url, @"https://example.com");
}

- (void)testRequest_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCRequest *req = [[SentryObjCRequest alloc] init];
    req.url = @"https://example.com";
    event.request = req;

    // -- Act --
    event.request = nil;

    // -- Assert --
    XCTAssertNil(event.request);
}

@end
