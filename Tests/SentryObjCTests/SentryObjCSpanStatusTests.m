@import SentryObjC;
@import XCTest;

@interface SentryObjCSpanStatusTests : XCTestCase
@end

@implementation SentryObjCSpanStatusTests

- (void)testSpanStatus_shouldMapAllCasesToExpectedValues
{
    // -- Assert --
    XCTAssertEqual(SentryObjCSpanStatusUndefined, (NSUInteger)0);
    XCTAssertEqual(SentryObjCSpanStatusOk, (NSUInteger)1);
    XCTAssertEqual(SentryObjCSpanStatusDeadlineExceeded, (NSUInteger)2);
    XCTAssertEqual(SentryObjCSpanStatusUnauthenticated, (NSUInteger)3);
    XCTAssertEqual(SentryObjCSpanStatusPermissionDenied, (NSUInteger)4);
    XCTAssertEqual(SentryObjCSpanStatusNotFound, (NSUInteger)5);
    XCTAssertEqual(SentryObjCSpanStatusResourceExhausted, (NSUInteger)6);
    XCTAssertEqual(SentryObjCSpanStatusInvalidArgument, (NSUInteger)7);
    XCTAssertEqual(SentryObjCSpanStatusUnimplemented, (NSUInteger)8);
    XCTAssertEqual(SentryObjCSpanStatusUnavailable, (NSUInteger)9);
    XCTAssertEqual(SentryObjCSpanStatusInternalError, (NSUInteger)10);
    XCTAssertEqual(SentryObjCSpanStatusUnknownError, (NSUInteger)11);
    XCTAssertEqual(SentryObjCSpanStatusCancelled, (NSUInteger)12);
    XCTAssertEqual(SentryObjCSpanStatusAlreadyExists, (NSUInteger)13);
    XCTAssertEqual(SentryObjCSpanStatusFailedPrecondition, (NSUInteger)14);
    XCTAssertEqual(SentryObjCSpanStatusAborted, (NSUInteger)15);
    XCTAssertEqual(SentryObjCSpanStatusOutOfRange, (NSUInteger)16);
    XCTAssertEqual(SentryObjCSpanStatusDataLoss, (NSUInteger)17);
}

- (void)testSpanStatus_whenRoundTripped_shouldPreserveValue
{
    // -- Act --
    SentryObjCSpanStatus roundTripped = (SentryObjCSpanStatus)SentryObjCSpanStatusOk;

    // -- Assert --
    XCTAssertEqual(roundTripped, SentryObjCSpanStatusOk);
}

@end
