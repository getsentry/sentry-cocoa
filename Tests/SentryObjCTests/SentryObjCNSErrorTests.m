@import SentryObjC;
@import XCTest;

@interface SentryObjCNSErrorTests : XCTestCase
@end

@implementation SentryObjCNSErrorTests

- (void)testInit_whenDomainAndCode_shouldSetBoth
{
    // -- Arrange & Act --
    SentryObjCNSError *error = [[SentryObjCNSError alloc] initWithDomain:@"NSCocoaErrorDomain"
                                                                    code:-1];

    // -- Assert --
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, @"NSCocoaErrorDomain");
    XCTAssertEqual(error.code, -1);
}

- (void)testDomain_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCNSError *error = [[SentryObjCNSError alloc] initWithDomain:@"NSCocoaErrorDomain"
                                                                    code:-1];

    // -- Act --
    error.domain = @"CustomDomain";

    // -- Assert --
    XCTAssertEqualObjects(error.domain, @"CustomDomain");
}

- (void)testCode_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCNSError *error = [[SentryObjCNSError alloc] initWithDomain:@"NSCocoaErrorDomain"
                                                                    code:-1];

    // -- Act --
    error.code = 404;

    // -- Assert --
    XCTAssertEqual(error.code, 404);
}

- (void)testCode_whenSetToZero_shouldReturnZero
{
    // -- Arrange --
    SentryObjCNSError *error = [[SentryObjCNSError alloc] initWithDomain:@"NSCocoaErrorDomain"
                                                                    code:-1];

    // -- Act --
    error.code = 0;

    // -- Assert --
    XCTAssertEqual(error.code, 0);
}

@end
