@import SentryObjC;
@import XCTest;

@interface SentryObjCScopeTests : XCTestCase
@end

@implementation SentryObjCScopeTests

- (void)testInit_whenDefault_shouldCreateInstance
{
    // -- Arrange & Act --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Assert --
    XCTAssertNotNil(scope);
}

- (void)testInitWithMaxBreadcrumbs_whenProvided_shouldCreateInstance
{
    // -- Arrange & Act --
    SentryObjCScope *scope = [[SentryObjCScope alloc] initWithMaxBreadcrumbs:10];

    // -- Assert --
    XCTAssertNotNil(scope);
}

- (void)testReplayId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    scope.replayId = @"replay-abc";

    // -- Assert --
    XCTAssertEqualObjects(scope.replayId, @"replay-abc");
}

- (void)testReplayId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    scope.replayId = @"replay-abc";

    // -- Act --
    scope.replayId = nil;

    // -- Assert --
    XCTAssertNil(scope.replayId);
}

- (void)testSetTagValueForKey_whenCalled_shouldBeReadableViaTags
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    [scope setTagValue:@"val1" forKey:@"key1"];

    // -- Assert --
    XCTAssertEqualObjects(scope.tags[@"key1"], @"val1");
}

- (void)testRemoveTagForKey_whenCalled_shouldRemoveTag
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTagValue:@"val1" forKey:@"key1"];

    // -- Act --
    [scope removeTagForKey:@"key1"];

    // -- Assert --
    XCTAssertNil(scope.tags[@"key1"]);
}

- (void)testSetTags_whenDictionary_shouldReplaceAllTags
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    [scope setTags:@{ @"a" : @"1", @"b" : @"2" }];

    // -- Assert --
    XCTAssertEqualObjects(scope.tags[@"a"], @"1");
    XCTAssertEqualObjects(scope.tags[@"b"], @"2");
}

- (void)testSetTags_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTags:@{ @"a" : @"1" }];

    // -- Act & Assert (no crash, tags unchanged) --
    [scope setTags:nil];
    XCTAssertEqualObjects(scope.tags[@"a"], @"1");
}

- (void)testSetUser_whenProvided_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    SentryObjCUser *user = [[SentryObjCUser alloc] initWithUserId:@"u1"];

    // -- Act & Assert (no crash) --
    [scope setUser:user];
}

- (void)testSetUser_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setUser:[[SentryObjCUser alloc] initWithUserId:@"u1"]];

    // -- Act & Assert (no crash) --
    [scope setUser:nil];
}

- (void)testSetExtras_whenDictionary_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setExtras:@{ @"extra1" : @"value1" }];
}

- (void)testSetExtras_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setExtras:@{ @"extra1" : @"value1" }];

    // -- Act & Assert (no crash) --
    [scope setExtras:nil];
}

- (void)testSetExtraValueForKey_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setExtraValue:@"ev" forKey:@"ek"];
}

- (void)testRemoveExtraForKey_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setExtraValue:@"ev" forKey:@"ek"];

    // -- Act & Assert (no crash) --
    [scope removeExtraForKey:@"ek"];
}

- (void)testSetDist_whenProvided_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setDist:@"100"];
}

- (void)testSetDist_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setDist:@"100"];

    // -- Act & Assert (no crash) --
    [scope setDist:nil];
}

- (void)testSetEnvironment_whenProvided_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setEnvironment:@"production"];
}

- (void)testSetEnvironment_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setEnvironment:@"production"];

    // -- Act & Assert (no crash) --
    [scope setEnvironment:nil];
}

- (void)testSetFingerprint_whenProvided_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setFingerprint:@[ @"fp1", @"fp2" ]];
}

- (void)testSetFingerprint_whenNil_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setFingerprint:@[ @"fp1" ]];

    // -- Act & Assert (no crash) --
    [scope setFingerprint:nil];
}

- (void)testSetLevel_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setLevel:SentryObjCLevelWarning];
}

- (void)testAddBreadcrumb_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"ui"];

    // -- Act & Assert (no crash) --
    [scope addBreadcrumb:crumb];
}

- (void)testClearBreadcrumbs_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"ui"];
    [scope addBreadcrumb:crumb];

    // -- Act & Assert (no crash) --
    [scope clearBreadcrumbs];
}

- (void)testSetContextValueForKey_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act & Assert (no crash) --
    [scope setContextValue:@{ @"device" : @"iPhone" } forKey:@"device"];
}

- (void)testRemoveContextForKey_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setContextValue:@{ @"device" : @"iPhone" } forKey:@"device"];

    // -- Act & Assert (no crash) --
    [scope removeContextForKey:@"device"];
}

- (void)testAddAttachment_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    NSData *data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithData:data
                                                                         filename:@"test.txt"];

    // -- Act & Assert (no crash) --
    [scope addAttachment:attachment];
}

- (void)testClearAttachments_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    NSData *data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCAttachment *attachment = [[SentryObjCAttachment alloc] initWithData:data
                                                                         filename:@"test.txt"];
    [scope addAttachment:attachment];

    // -- Act & Assert (no crash) --
    [scope clearAttachments];
}

- (void)testSetAttributeValueForKey_whenCalled_shouldBeReadableViaAttributes
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    [scope setAttributeValue:@"attrVal" forKey:@"attrKey"];

    // -- Assert --
    XCTAssertNotNil(scope.attributes);
    XCTAssertEqualObjects(scope.attributes[@"attrKey"], @"attrVal");
}

- (void)testRemoveAttributeForKey_whenCalled_shouldRemoveAttribute
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setAttributeValue:@"attrVal" forKey:@"attrKey"];

    // -- Act --
    [scope removeAttributeForKey:@"attrKey"];

    // -- Assert --
    XCTAssertNil(scope.attributes[@"attrKey"]);
}

- (void)testSpan_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Assert --
    XCTAssertNil(scope.span);
}

- (void)testSpan_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    scope.span = nil;

    // -- Assert --
    XCTAssertNil(scope.span);
}

- (void)testSpan_whenSetToSpan_shouldReturnSpan
{
    // -- Arrange --
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
        options.tracesSampleRate = @1.0;
    }];
    SentryObjCSpan *transaction = [SentryObjCSDK startTransactionWithName:@"test" operation:@"op"];
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    scope.span = transaction;

    // -- Assert --
    XCTAssertNotNil(scope.span);

    // -- Cleanup --
    [transaction finish];
    [SentryObjCSDK close];
}

- (void)testSerialize_whenDefault_shouldReturnDictionary
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];

    // -- Act --
    NSDictionary<NSString *, id> *result = [scope serialize];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testSerialize_whenTagsSet_shouldIncludeTagsInResult
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTagValue:@"val" forKey:@"key"];

    // -- Act --
    NSDictionary<NSString *, id> *result = [scope serialize];

    // -- Assert --
    XCTAssertNotNil(result);
    NSDictionary *tags = result[@"tags"];
    XCTAssertEqualObjects(tags[@"key"], @"val");
}

- (void)testClear_whenCalled_shouldNotCrash
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTagValue:@"val" forKey:@"key"];
    [scope setAttributeValue:@"av" forKey:@"ak"];

    // -- Act & Assert (no crash) --
    [scope clear];
}

@end
