@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalScopeApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalScopeApiIntegrationTests

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

- (void)testSerializedContexts_whenScopeContainsCustomContext_shouldReturnEventContexts
{
    // -- Arrange --
    [SentryObjCSDK configureScope:^(SentryObjCScope *scope) {
        [scope setContextValue:@ { @"value" : @"test" } forKey:@"hybrid"];
    }];

    // -- Act --
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *contexts =
        [SentryObjCSDK.internal.scope serializedContexts];

    // -- Assert --
    XCTAssertEqualObjects(contexts[@"hybrid"][@"value"], @"test");
    XCTAssertNotNil(contexts[@"trace"]);
}

#pragma mark - createScope / cloneScope

- (void)testCreateScope_shouldReturnUsableScope
{
    SentryObjCScope *scope = [SentryObjCSDK createScope];
    XCTAssertNotNil(scope);
    [scope setTagValue:@"value" forKey:@"key"];
    XCTAssertEqualObjects(scope.tags[@"key"], @"value");
}

- (void)testCloneScope_shouldReturnIndependentCopy
{
    SentryObjCScope *original = [SentryObjCSDK createScope];
    [original setTagValue:@"v1" forKey:@"key"];

    SentryObjCScope *clone = [SentryObjCSDK cloneScope:original];
    [clone setTagValue:@"v2" forKey:@"key"];

    XCTAssertEqualObjects(original.tags[@"key"], @"v1");
    XCTAssertEqualObjects(clone.tags[@"key"], @"v2");
}

#pragma mark - captureEvent with currentScope

- (void)testCaptureEvent_withCurrentScope_shouldNotCrash
{
    // -- Arrange --
    [SentryObjCSDK configureScope:^(
        SentryObjCScope *scope) { [scope setTagValue:@"global" forKey:@"global_tag"]; }];

    SentryObjCScope *currentScope = [SentryObjCSDK createScope];
    [currentScope setTagValue:@"current" forKey:@"current_tag"];

    // -- Act & Assert (no crash) --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    SentryObjCId *eventId = [SentryObjCSDK captureEvent:event withCurrentScope:currentScope];
    XCTAssertNotNil(eventId);
}

@end
