#import "SentryError.h"
#import <XCTest/XCTest.h>
#import <mach/kern_return.h>

@interface SentryDeprecatedErrorAPIObjCTests : XCTestCase

@end

@implementation SentryDeprecatedErrorAPIObjCTests

- (void)testDomain_shouldMatchErrorDomainLiteral
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(SentryErrorDomain, @"SentryErrorDomain");
#pragma clang diagnostic pop
}

- (void)testErrorWithDescription_shouldUseCaseCodeAndDomain
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSError *error = NSErrorFromSentryError(kSentryErrorFileIO, @"disk full");
    XCTAssertEqualObjects(error.domain, @"SentryErrorDomain");
    XCTAssertEqual(error.code, kSentryErrorFileIO);
    XCTAssertEqualObjects(error.localizedDescription, @"disk full");
#pragma clang diagnostic pop
}

- (void)testErrorWithUnderlyingError_shouldStoreUnderlyingError
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSError *underlying = [NSError errorWithDomain:@"underlying" code:4 userInfo:nil];
    NSError *wrapped = NSErrorFromSentryErrorWithUnderlyingError(
        kSentryErrorRequestError, @"request failed", underlying);
    XCTAssertEqualObjects(wrapped.localizedDescription, @"request failed");
    XCTAssertEqualObjects(wrapped.userInfo[NSUnderlyingErrorKey], underlying);
#pragma clang diagnostic pop
}

- (void)testErrorWithException_shouldAppendReason
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSException *exception = [NSException exceptionWithName:@"Test" reason:@"boom" userInfo:nil];
    NSError *exceptionError
        = NSErrorFromSentryErrorWithException(kSentryErrorUnknownError, @"failed", exception);
    XCTAssertEqualObjects(exceptionError.localizedDescription, @"failed (boom)");
#pragma clang diagnostic pop
}

- (void)testErrorWithKernelError_shouldAppendKernelDescription
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSError *kernelError
        = NSErrorFromSentryErrorWithKernelError(kSentryErrorKernel, @"mach", KERN_NOT_RECEIVER);
    XCTAssertEqualObjects(kernelError.localizedDescription,
        @"mach (The task in question does not hold receive rights for the port argument.)");
#pragma clang diagnostic pop
}

@end
