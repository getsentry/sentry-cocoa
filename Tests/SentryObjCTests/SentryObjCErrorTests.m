@import SentryObjC;
@import XCTest;

@interface SentryObjCErrorTests : XCTestCase
@end

@implementation SentryObjCErrorTests

- (void)testNSErrorWithCode_shouldUseCodeDescriptionAndSdkDomain
{
    // -- Act --
    NSError *error = [SentryObjCError nsErrorWithCode:SentryObjCErrorCodeFileIO
                                          description:@"disk full"];

    // -- Assert --
    XCTAssertEqual(error.code, SentryObjCErrorCodeFileIO);
    XCTAssertEqualObjects(error.domain, @"SentryErrorDomain");
    XCTAssertEqualObjects(error.localizedDescription, @"disk full");
}

@end
