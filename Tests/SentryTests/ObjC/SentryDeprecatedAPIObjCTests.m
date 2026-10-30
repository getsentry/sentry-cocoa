#import "SentryDefines.h"
#import "SentryDeprecated.h"
#import "SentryError.h"
#import "SentrySpanStatus.h"
#import <XCTest/XCTest.h>
#import <mach/kern_return.h>

@interface SentryDeprecatedAPIObjCTests : XCTestCase

@end

@implementation SentryDeprecatedAPIObjCTests

- (void)testDeprecatedSymbols_shouldMatchWireLiterals
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(SentryErrorDomain, @"SentryErrorDomain");

    NSError *error = NSErrorFromSentryError(kSentryErrorFileIO, @"disk full");
    XCTAssertEqualObjects(error.domain, @"SentryErrorDomain");
    XCTAssertEqual(error.code, kSentryErrorFileIO);
    XCTAssertEqualObjects(error.localizedDescription, @"disk full");

    NSError *underlying = [NSError errorWithDomain:@"underlying" code:4 userInfo:nil];
    NSError *wrapped = NSErrorFromSentryErrorWithUnderlyingError(
        kSentryErrorRequestError, @"request failed", underlying);
    XCTAssertEqualObjects(wrapped.localizedDescription, @"request failed");
    XCTAssertEqualObjects(wrapped.userInfo[NSUnderlyingErrorKey], underlying);

    NSException *exception = [NSException exceptionWithName:@"Test" reason:@"boom" userInfo:nil];
    NSError *exceptionError
        = NSErrorFromSentryErrorWithException(kSentryErrorUnknownError, @"failed", exception);
    XCTAssertEqualObjects(exceptionError.localizedDescription, @"failed (boom)");

    NSError *kernelError
        = NSErrorFromSentryErrorWithKernelError(kSentryErrorKernel, @"mach", KERN_NOT_RECEIVER);
    XCTAssertEqualObjects(kernelError.localizedDescription,
        @"mach (The task in question does not hold receive rights for the port argument.)");

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

    XCTAssertEqualObjects(SENTRY_BAGGAGE_HEADER, @"baggage");
    XCTAssertEqualObjects(SENTRY_TRACE_HEADER, @"sentry-trace");
    XCTAssertEqualObjects(SENTRY_TRACE_TYPE, @"trace");
    XCTAssertEqual(defaultMaxBreadcrumbs, 100);
    XCTAssertEqualObjects(kSentryTrueString, @"true");
    XCTAssertEqualObjects(kSentryFalseString, @"false");
#pragma clang diagnostic pop
}

@end
