@import SentryObjC;
@import XCTest;

@interface SentryObjCThreadTests : XCTestCase
@end

@implementation SentryObjCThreadTests

#pragma mark - SentryObjCThread

- (void)testInit_whenThreadId_shouldSetThreadId
{
    // -- Arrange & Act --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Assert --
    XCTAssertNotNil(thread);
    XCTAssertEqualObjects(thread.threadId, @1);
}

- (void)testInit_whenNilThreadId_shouldSetNil
{
    // -- Arrange & Act --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:nil];

    // -- Assert --
    XCTAssertNotNil(thread);
    XCTAssertNil(thread.threadId);
}

- (void)testThreadId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.threadId = @99;

    // -- Assert --
    XCTAssertEqualObjects(thread.threadId, @99);
}

- (void)testThreadId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.threadId = nil;

    // -- Assert --
    XCTAssertNil(thread.threadId);
}

- (void)testName_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    NSString *result = thread.name;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testName_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.name = @"main";

    // -- Assert --
    XCTAssertEqualObjects(thread.name, @"main");
}

- (void)testName_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    thread.name = @"main";

    // -- Act --
    thread.name = nil;

    // -- Assert --
    XCTAssertNil(thread.name);
}

- (void)testStacktrace_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    SentryObjCStacktrace *result = thread.stacktrace;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStacktrace_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    thread.stacktrace = st;

    // -- Assert --
    XCTAssertNotNil(thread.stacktrace);
}

- (void)testStacktrace_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    thread.stacktrace = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ] registers:@{ }];

    // -- Act --
    thread.stacktrace = nil;

    // -- Assert --
    XCTAssertNil(thread.stacktrace);
}

- (void)testCrashed_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    NSNumber *result = thread.crashed;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testCrashed_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.crashed = @YES;

    // -- Assert --
    XCTAssertEqualObjects(thread.crashed, @YES);
}

- (void)testCrashed_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    thread.crashed = @YES;

    // -- Act --
    thread.crashed = nil;

    // -- Assert --
    XCTAssertNil(thread.crashed);
}

- (void)testCurrent_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    NSNumber *result = thread.current;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testCurrent_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.current = @YES;

    // -- Assert --
    XCTAssertEqualObjects(thread.current, @YES);
}

- (void)testCurrent_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    thread.current = @YES;

    // -- Act --
    thread.current = nil;

    // -- Assert --
    XCTAssertNil(thread.current);
}

- (void)testIsMain_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    NSNumber *result = thread.isMain;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testIsMain_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Act --
    thread.isMain = @NO;

    // -- Assert --
    XCTAssertEqualObjects(thread.isMain, @NO);
}

- (void)testIsMain_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    thread.isMain = @NO;

    // -- Act --
    thread.isMain = nil;

    // -- Assert --
    XCTAssertNil(thread.isMain);
}

#pragma mark - SentryObjCStacktrace

- (void)testStacktraceInit_whenFramesAndRegisters_shouldSetBoth
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.function = @"main";
    NSDictionary *registers = @{ @"rip" : @"0xdeadbeef" };

    // -- Act --
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:registers];

    // -- Assert --
    XCTAssertNotNil(st);
    XCTAssertEqual(st.frames.count, 1u);
    XCTAssertEqualObjects(st.frames.firstObject.function, @"main");
    XCTAssertEqualObjects(st.registers[@"rip"], @"0xdeadbeef");
}

- (void)testStacktraceFrames_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    st.frames = @[];

    // -- Assert --
    XCTAssertEqual(st.frames.count, 0u);
}

- (void)testStacktraceRegisters_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st =
        [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                           registers:@{ @"rip" : @"0xdeadbeef" }];

    // -- Act --
    st.registers = @{ @"rsp" : @"0xcafebabe" };

    // -- Assert --
    XCTAssertEqualObjects(st.registers[@"rsp"], @"0xcafebabe");
}

- (void)testStacktraceSnapshot_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    NSNumber *result = st.snapshot;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testStacktraceSnapshot_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    st.snapshot = @YES;

    // -- Assert --
    XCTAssertEqualObjects(st.snapshot, @YES);
}

- (void)testStacktraceSnapshot_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];
    st.snapshot = @YES;

    // -- Act --
    st.snapshot = nil;

    // -- Assert --
    XCTAssertNil(st.snapshot);
}

@end
