#import "SentrySpanStatus.h"
#import <XCTest/XCTest.h>

@interface SentryDeprecatedSpanStatusAPIObjCTests : XCTestCase

@end

@implementation SentryDeprecatedSpanStatusAPIObjCTests

- (void)testSpanStatusNames_shouldMatchWireLiterals
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(nameForSentrySpanStatus(kSentrySpanStatusOk), @"ok");
    XCTAssertEqualObjects(
        nameForSentrySpanStatus(kSentrySpanStatusDeadlineExceeded), @"deadline_exceeded");
    XCTAssertEqualObjects(kSentrySpanStatusNameUndefined, @"undefined");
    XCTAssertEqualObjects(kSentrySpanStatusNameOk, @"ok");
    XCTAssertEqualObjects(kSentrySpanStatusNameDeadlineExceeded, @"deadline_exceeded");
    XCTAssertEqualObjects(kSentrySpanStatusNameUnauthenticated, @"unauthenticated");
    XCTAssertEqualObjects(kSentrySpanStatusNamePermissionDenied, @"permission_denied");
    XCTAssertEqualObjects(kSentrySpanStatusNameNotFound, @"not_found");
    XCTAssertEqualObjects(kSentrySpanStatusNameResourceExhausted, @"resource_exhausted");
    XCTAssertEqualObjects(kSentrySpanStatusNameInvalidArgument, @"invalid_argument");
    XCTAssertEqualObjects(kSentrySpanStatusNameUnimplemented, @"unimplemented");
    XCTAssertEqualObjects(kSentrySpanStatusNameUnavailable, @"unavailable");
    XCTAssertEqualObjects(kSentrySpanStatusNameInternalError, @"internal_error");
    XCTAssertEqualObjects(kSentrySpanStatusNameUnknownError, @"unknown_error");
    XCTAssertEqualObjects(kSentrySpanStatusNameCancelled, @"cancelled");
    XCTAssertEqualObjects(kSentrySpanStatusNameAlreadyExists, @"already_exists");
    XCTAssertEqualObjects(kSentrySpanStatusNameFailedPrecondition, @"failed_precondition");
    XCTAssertEqualObjects(kSentrySpanStatusNameAborted, @"aborted");
    XCTAssertEqualObjects(kSentrySpanStatusNameOutOfRange, @"out_of_range");
    XCTAssertEqualObjects(kSentrySpanStatusNameDataLoss, @"data_loss");
#pragma clang diagnostic pop
}

@end
