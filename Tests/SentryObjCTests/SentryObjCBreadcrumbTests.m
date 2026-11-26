@import SentryObjC;
@import XCTest;

@interface SentryObjCBreadcrumbTests : XCTestCase
@end

@implementation SentryObjCBreadcrumbTests

- (void)testInit_whenDefault_shouldSetDefaults
{
    // -- Act --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] init];

    // -- Assert --
    XCTAssertNotNil(crumb);
    XCTAssertEqual(crumb.level, SentryObjCLevelInfo);
    XCTAssertEqualObjects(crumb.category, @"default");
    XCTAssertNotNil(crumb.timestamp);
}

- (void)testInit_whenLevelAndCategory_shouldSetBoth
{
    // -- Arrange --
    SentryObjCLevel level = SentryObjCLevelInfo;

    // -- Act --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:level
                                                                     category:@"navigation"];

    // -- Assert --
    XCTAssertNotNil(crumb);
    XCTAssertEqual(crumb.level, SentryObjCLevelInfo);
    XCTAssertEqualObjects(crumb.category, @"navigation");
}

- (void)testLevel_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act --
    crumb.level = SentryObjCLevelError;

    // -- Assert --
    XCTAssertEqual(crumb.level, SentryObjCLevelError);
}

- (void)testCategory_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"navigation"];

    // -- Act --
    crumb.category = @"http";

    // -- Assert --
    XCTAssertEqualObjects(crumb.category, @"http");
}

- (void)testTimestamp_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];
    NSDate *now = [NSDate date];

    // -- Act --
    crumb.timestamp = now;

    // -- Assert --
    XCTAssertEqualObjects(crumb.timestamp, now);
}

- (void)testTimestamp_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];
    crumb.timestamp = [NSDate date];

    // -- Act --
    crumb.timestamp = nil;

    // -- Assert --
    XCTAssertNil(crumb.timestamp);
}

- (void)testType_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act --
    crumb.type = @"http";

    // -- Assert --
    XCTAssertEqualObjects(crumb.type, @"http");
}

- (void)testMessage_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act --
    crumb.message = @"navigated to /home";

    // -- Assert --
    XCTAssertEqualObjects(crumb.message, @"navigated to /home");
}

- (void)testOrigin_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act --
    crumb.origin = @"auto.ui";

    // -- Assert --
    XCTAssertEqualObjects(crumb.origin, @"auto.ui");
}

#if SDK_V10
- (void)testData_whenReadOnly_shouldNotExposeWholeDictionarySetter
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] init];

    // -- Assert --
    XCTAssertFalse([crumb respondsToSelector:NSSelectorFromString(@"setData:")]);
}
#else
- (void)testData_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];

    // -- Act --
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    crumb.data = @{ @"url" : @"/home" };
#    pragma clang diagnostic pop

    // -- Assert --
    XCTAssertEqualObjects(crumb.data[@"url"], @"/home");
}

- (void)testData_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] initWithLevel:SentryObjCLevelInfo
                                                                     category:@"test"];
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wdeprecated-declarations"
    crumb.data = @{ @"key" : @"value" };

    // -- Act --
    crumb.data = nil;
#    pragma clang diagnostic pop

    // -- Assert --
    XCTAssertNil(crumb.data);
}
#endif

- (void)testSetDataValueForKey_whenUpdatingData_shouldMergeAndRemoveValues
{
    // -- Arrange --
    SentryObjCBreadcrumb *crumb = [[SentryObjCBreadcrumb alloc] init];

    // -- Act --
    [crumb setDataValue:@"/home" forKey:@"url"];
    [crumb setDataValue:@"wifi" forKey:@"connectivity"];
    [crumb setDataValue:@"/settings" forKey:@"url"];
    [crumb setDataValue:nil forKey:@"connectivity"];

    // -- Assert --
    XCTAssertEqualObjects(crumb.data, (@{ @"url" : @"/settings" }));
}

@end
