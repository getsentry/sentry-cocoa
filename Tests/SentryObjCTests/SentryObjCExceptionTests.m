@import SentryObjC;
@import XCTest;

@interface SentryObjCExceptionTests : XCTestCase
@end

@implementation SentryObjCExceptionTests

- (void)testInit_whenValueAndType_shouldSetBoth
{
    // -- Arrange & Act --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Assert --
    XCTAssertNotNil(exception);
    XCTAssertEqualObjects(exception.value, @"crash");
    XCTAssertEqualObjects(exception.type, @"NSException");
}

- (void)testInit_whenNilValue_shouldSetNilValue
{
    // -- Arrange & Act --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:nil
                                                                           type:@"NSException"];

    // -- Assert --
    XCTAssertNotNil(exception);
    XCTAssertNil(exception.value);
    XCTAssertEqualObjects(exception.type, @"NSException");
}

- (void)testInit_whenNilType_shouldSetNilType
{
    // -- Arrange & Act --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash" type:nil];

    // -- Assert --
    XCTAssertNotNil(exception);
    XCTAssertEqualObjects(exception.value, @"crash");
    XCTAssertNil(exception.type);
}

- (void)testValue_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.value = @"updated";

    // -- Assert --
    XCTAssertEqualObjects(exception.value, @"updated");
}

- (void)testValue_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.value = nil;

    // -- Assert --
    XCTAssertNil(exception.value);
}

- (void)testType_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.type = @"RuntimeError";

    // -- Assert --
    XCTAssertEqualObjects(exception.type, @"RuntimeError");
}

- (void)testType_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.type = nil;

    // -- Assert --
    XCTAssertNil(exception.type);
}

- (void)testMechanism_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    SentryObjCMechanism *result = exception.mechanism;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testMechanism_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    SentryObjCMechanism *mech = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    exception.mechanism = mech;

    // -- Assert --
    XCTAssertNotNil(exception.mechanism);
}

- (void)testMechanism_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    exception.mechanism = [[SentryObjCMechanism alloc] initWithType:@"generic"];

    // -- Act --
    exception.mechanism = nil;

    // -- Assert --
    XCTAssertNil(exception.mechanism);
}

- (void)testModule_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    NSString *result = exception.module;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testModule_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.module = @"MyModule";

    // -- Assert --
    XCTAssertEqualObjects(exception.module, @"MyModule");
}

- (void)testModule_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    exception.module = @"MyModule";

    // -- Act --
    exception.module = nil;

    // -- Assert --
    XCTAssertNil(exception.module);
}

- (void)testThreadId_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    NSNumber *result = exception.threadId;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testThreadId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    exception.threadId = @42;

    // -- Assert --
    XCTAssertEqualObjects(exception.threadId, @42);
}

- (void)testThreadId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    exception.threadId = @42;

    // -- Act --
    exception.threadId = nil;

    // -- Assert --
    XCTAssertNil(exception.threadId);
}

- (void)testStacktrace_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];

    // -- Act --
    SentryObjCStacktrace *result = exception.stacktrace;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStacktrace_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    exception.stacktrace = st;

    // -- Assert --
    XCTAssertNotNil(exception.stacktrace);
}

- (void)testStacktrace_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCException *exception = [[SentryObjCException alloc] initWithValue:@"crash"
                                                                           type:@"NSException"];
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    exception.stacktrace = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ] registers:@{ }];

    // -- Act --
    exception.stacktrace = nil;

    // -- Assert --
    XCTAssertNil(exception.stacktrace);
}

@end
