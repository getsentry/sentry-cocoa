#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCThreadTests : XCTestCase
@end

@implementation SentryObjCThreadTests

#pragma mark - SentryObjCThread

- (void)testInit_whenThreadId_shouldSetThreadId
{
    // -- Act --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];

    // -- Assert --
    XCTAssertEqualObjects(thread.threadId, @1);
}

- (void)testInit_whenNilThreadId_shouldSetNil
{
    // -- Act --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:nil];

    // -- Assert --
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

    // -- Assert --
    XCTAssertNil(thread.name);
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

    // -- Assert --
    XCTAssertNil(thread.stacktrace);
}

- (void)testStacktrace_whenSet_shouldReturnValueWithFrames
{
    // -- Arrange --
    SentryObjCThread *thread = [[SentryObjCThread alloc] initWithThreadId:@1];
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.function = @"main";
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:@{ }];

    // -- Act --
    thread.stacktrace = st;

    // -- Assert --
    XCTAssertEqual(thread.stacktrace.frames.count, 1u);
    XCTAssertEqualObjects(thread.stacktrace.frames.firstObject.function, @"main");
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

    // -- Assert --
    XCTAssertNil(thread.crashed);
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

    // -- Assert --
    XCTAssertNil(thread.current);
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

    // -- Assert --
    XCTAssertNil(thread.isMain);
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

- (void)testStacktraceInit_shouldSetFramesAndRegisters
{
    // -- Arrange --
    SentryObjCFrame *frame = [[SentryObjCFrame alloc] init];
    frame.function = @"main";
    NSDictionary *registers = @{ @"rip" : @"0xdeadbeef" };

    // -- Act --
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[ frame ]
                                                                  registers:registers];

    // -- Assert --
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
    SentryObjCStacktrace *st =
        [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ @"rip" : @"0xdeadbeef" }];

    // -- Act --
    st.registers = @{ @"rsp" : @"0xcafebabe" };

    // -- Assert --
    XCTAssertEqualObjects(st.registers[@"rsp"], @"0xcafebabe");
    XCTAssertNil(st.registers[@"rip"]);
}

- (void)testStacktraceSnapshot_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ }];

    // -- Assert --
    XCTAssertNil(st.snapshot);
}

- (void)testStacktraceSnapshot_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ }];

    // -- Act --
    st.snapshot = @YES;

    // -- Assert --
    XCTAssertEqualObjects(st.snapshot, @YES);
}

- (void)testStacktraceSnapshot_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCStacktrace *st = [[SentryObjCStacktrace alloc] initWithFrames:@[] registers:@{ }];
    st.snapshot = @YES;

    // -- Act --
    st.snapshot = nil;

    // -- Assert --
    XCTAssertNil(st.snapshot);
}

@end
