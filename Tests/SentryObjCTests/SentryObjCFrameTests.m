@import SentryObjC;
@import XCTest;

@interface SentryObjCFrameTests : XCTestCase
@end

@implementation SentryObjCFrameTests

- (void)testInit_shouldBeNotNil
{
    // -- Arrange & Act --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Assert --
    XCTAssertNotNil(frame);
}

#pragma mark - symbolAddress

- (void)testSymbolAddress_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.symbolAddress = @"0x1000";

    // -- Assert --
    XCTAssertEqualObjects(frame.symbolAddress, @"0x1000");
}

- (void)testSymbolAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.symbolAddress = @"0x1";

    // -- Act --
    frame.symbolAddress = nil;

    // -- Assert --
    XCTAssertNil(frame.symbolAddress);
}

#pragma mark - fileName

- (void)testFileName_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.fileName = @"index.js";

    // -- Assert --
    XCTAssertEqualObjects(frame.fileName, @"index.js");
}

- (void)testFileName_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.fileName = @"a";

    // -- Act --
    frame.fileName = nil;

    // -- Assert --
    XCTAssertNil(frame.fileName);
}

#pragma mark - function

- (void)testFunction_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.function = @"-[AppDelegate main]";

    // -- Assert --
    XCTAssertEqualObjects(frame.function, @"-[AppDelegate main]");
}

- (void)testFunction_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.function = @"a";

    // -- Act --
    frame.function = nil;

    // -- Assert --
    XCTAssertNil(frame.function);
}

#pragma mark - module

- (void)testModule_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.module = @"MyApp";

    // -- Assert --
    XCTAssertEqualObjects(frame.module, @"MyApp");
}

- (void)testModule_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.module = @"a";

    // -- Act --
    frame.module = nil;

    // -- Assert --
    XCTAssertNil(frame.module);
}

#pragma mark - package

- (void)testPackage_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.package = @"/usr/lib/libSystem.B.dylib";

    // -- Assert --
    XCTAssertEqualObjects(frame.package, @"/usr/lib/libSystem.B.dylib");
}

- (void)testPackage_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.package = @"a";

    // -- Act --
    frame.package = nil;

    // -- Assert --
    XCTAssertNil(frame.package);
}

#pragma mark - imageAddress

- (void)testImageAddress_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.imageAddress = @"0x0";

    // -- Assert --
    XCTAssertEqualObjects(frame.imageAddress, @"0x0");
}

- (void)testImageAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.imageAddress = @"a";

    // -- Act --
    frame.imageAddress = nil;

    // -- Assert --
    XCTAssertNil(frame.imageAddress);
}

#pragma mark - platform

- (void)testPlatform_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.platform = @"javascript";

    // -- Assert --
    XCTAssertEqualObjects(frame.platform, @"javascript");
}

- (void)testPlatform_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.platform = @"a";

    // -- Act --
    frame.platform = nil;

    // -- Assert --
    XCTAssertNil(frame.platform);
}

#pragma mark - instructionAddress

- (void)testInstructionAddress_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.instructionAddress = @"0xdeadbeef";

    // -- Assert --
    XCTAssertEqualObjects(frame.instructionAddress, @"0xdeadbeef");
}

- (void)testInstructionAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.instructionAddress = @"a";

    // -- Act --
    frame.instructionAddress = nil;

    // -- Assert --
    XCTAssertNil(frame.instructionAddress);
}

#pragma mark - lineNumber

- (void)testLineNumber_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.lineNumber = @42;

    // -- Assert --
    XCTAssertEqualObjects(frame.lineNumber, @42);
}

- (void)testLineNumber_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.lineNumber = @1;

    // -- Act --
    frame.lineNumber = nil;

    // -- Assert --
    XCTAssertNil(frame.lineNumber);
}

#pragma mark - columnNumber

- (void)testColumnNumber_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.columnNumber = @13;

    // -- Assert --
    XCTAssertEqualObjects(frame.columnNumber, @13);
}

- (void)testColumnNumber_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.columnNumber = @1;

    // -- Act --
    frame.columnNumber = nil;

    // -- Assert --
    XCTAssertNil(frame.columnNumber);
}

#pragma mark - contextLine

- (void)testContextLine_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.contextLine = @"let x = crash()";

    // -- Assert --
    XCTAssertEqualObjects(frame.contextLine, @"let x = crash()");
}

- (void)testContextLine_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.contextLine = @"a";

    // -- Act --
    frame.contextLine = nil;

    // -- Assert --
    XCTAssertNil(frame.contextLine);
}

#pragma mark - parentIndex

- (void)testParentIndex_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.parentIndex = @0;

    // -- Assert --
    XCTAssertEqualObjects(frame.parentIndex, @0);
}

- (void)testParentIndex_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.parentIndex = @0;

    // -- Act --
    frame.parentIndex = nil;

    // -- Assert --
    XCTAssertNil(frame.parentIndex);
}

#pragma mark - sampleCount

- (void)testSampleCount_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.sampleCount = @100;

    // -- Assert --
    XCTAssertEqualObjects(frame.sampleCount, @100);
}

- (void)testSampleCount_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.sampleCount = @1;

    // -- Act --
    frame.sampleCount = nil;

    // -- Assert --
    XCTAssertNil(frame.sampleCount);
}

#pragma mark - preContext

- (void)testPreContext_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.preContext = @[ @"line 1", @"line 2" ];

    // -- Assert --
    XCTAssertEqual(frame.preContext.count, 2u);
}

- (void)testPreContext_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.preContext = @[];

    // -- Act --
    frame.preContext = nil;

    // -- Assert --
    XCTAssertNil(frame.preContext);
}

#pragma mark - postContext

- (void)testPostContext_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.postContext = @[ @"line 4", @"line 5" ];

    // -- Assert --
    XCTAssertEqual(frame.postContext.count, 2u);
}

- (void)testPostContext_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.postContext = @[];

    // -- Act --
    frame.postContext = nil;

    // -- Assert --
    XCTAssertNil(frame.postContext);
}

#pragma mark - inApp

- (void)testInApp_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.inApp = @YES;

    // -- Assert --
    XCTAssertEqualObjects(frame.inApp, @YES);
}

- (void)testInApp_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.inApp = @YES;

    // -- Act --
    frame.inApp = nil;

    // -- Assert --
    XCTAssertNil(frame.inApp);
}

#pragma mark - stackStart

- (void)testStackStart_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.stackStart = @YES;

    // -- Assert --
    XCTAssertEqualObjects(frame.stackStart, @YES);
}

- (void)testStackStart_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.stackStart = @YES;

    // -- Act --
    frame.stackStart = nil;

    // -- Assert --
    XCTAssertNil(frame.stackStart);
}

#pragma mark - vars

- (void)testVars_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Act --
    frame.vars = @{ @"self" : @"<AppDelegate: 0x123>" };

    // -- Assert --
    XCTAssertEqualObjects(frame.vars[@"self"], @"<AppDelegate: 0x123>");
}

- (void)testVars_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.vars = @{ };

    // -- Act --
    frame.vars = nil;

    // -- Assert --
    XCTAssertNil(frame.vars);
}

#pragma mark - default nil values

- (void)testAllProperties_whenDefault_shouldReturnNil
{
    // -- Arrange & Act --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];

    // -- Assert --
    XCTAssertNil(frame.symbolAddress);
    XCTAssertNil(frame.fileName);
    XCTAssertNil(frame.function);
    XCTAssertNil(frame.module);
    XCTAssertNil(frame.package);
    XCTAssertNil(frame.imageAddress);
    XCTAssertNil(frame.platform);
    XCTAssertNil(frame.instructionAddress);
    XCTAssertNil(frame.lineNumber);
    XCTAssertNil(frame.columnNumber);
    XCTAssertNil(frame.contextLine);
    XCTAssertNil(frame.parentIndex);
    XCTAssertNil(frame.sampleCount);
    XCTAssertNil(frame.preContext);
    XCTAssertNil(frame.postContext);
    XCTAssertNil(frame.inApp);
    XCTAssertNil(frame.stackStart);
    XCTAssertNil(frame.vars);
}

@end
