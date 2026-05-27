@import SentryObjC;
@import XCTest;

@interface SentryObjCDebugMetaTests : XCTestCase
@end

@implementation SentryObjCDebugMetaTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    // -- Act --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNotNil(meta);
}

#pragma mark - debugID

- (void)testDebugID_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.debugID);
}

- (void)testDebugID_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.debugID = @"12c2d058d58442709aa2eca08bf20986";

    // -- Assert --
    XCTAssertEqualObjects(meta.debugID, @"12c2d058d58442709aa2eca08bf20986");
}

- (void)testDebugID_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.debugID = @"12c2d058d58442709aa2eca08bf20986";

    // -- Act --
    meta.debugID = nil;

    // -- Assert --
    XCTAssertNil(meta.debugID);
}

#pragma mark - type

- (void)testType_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.type);
}

- (void)testType_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.type = @"macho";

    // -- Assert --
    XCTAssertEqualObjects(meta.type, @"macho");
}

- (void)testType_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.type = @"macho";

    // -- Act --
    meta.type = nil;

    // -- Assert --
    XCTAssertNil(meta.type);
}

#pragma mark - imageSize

- (void)testImageSize_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.imageSize);
}

- (void)testImageSize_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.imageSize = @4096;

    // -- Assert --
    XCTAssertEqualObjects(meta.imageSize, @4096);
}

- (void)testImageSize_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.imageSize = @4096;

    // -- Act --
    meta.imageSize = nil;

    // -- Assert --
    XCTAssertNil(meta.imageSize);
}

#pragma mark - imageAddress

- (void)testImageAddress_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.imageAddress);
}

- (void)testImageAddress_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.imageAddress = @"0x100000000";

    // -- Assert --
    XCTAssertEqualObjects(meta.imageAddress, @"0x100000000");
}

- (void)testImageAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.imageAddress = @"0x100000000";

    // -- Act --
    meta.imageAddress = nil;

    // -- Assert --
    XCTAssertNil(meta.imageAddress);
}

#pragma mark - imageVmAddress

- (void)testImageVmAddress_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.imageVmAddress);
}

- (void)testImageVmAddress_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.imageVmAddress = @"0x100000000";

    // -- Assert --
    XCTAssertEqualObjects(meta.imageVmAddress, @"0x100000000");
}

- (void)testImageVmAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.imageVmAddress = @"0x100000000";

    // -- Act --
    meta.imageVmAddress = nil;

    // -- Assert --
    XCTAssertNil(meta.imageVmAddress);
}

#pragma mark - codeFile

- (void)testCodeFile_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Assert --
    XCTAssertNil(meta.codeFile);
}

- (void)testCodeFile_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];

    // -- Act --
    meta.codeFile = @"/usr/lib/libSystem.dylib";

    // -- Assert --
    XCTAssertEqualObjects(meta.codeFile, @"/usr/lib/libSystem.dylib");
}

- (void)testCodeFile_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCDebugMeta *meta = [[SentryObjCDebugMeta alloc] init];
    meta.codeFile = @"/usr/lib/libSystem.dylib";

    // -- Act --
    meta.codeFile = nil;

    // -- Assert --
    XCTAssertNil(meta.codeFile);
}

@end
