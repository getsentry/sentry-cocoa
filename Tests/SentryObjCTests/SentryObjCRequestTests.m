@import SentryObjC;
@import XCTest;

@interface SentryObjCRequestTests : XCTestCase
@end

@implementation SentryObjCRequestTests

- (void)testInit_shouldBeNotNil
{
    // -- Arrange & Act --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Assert --
    XCTAssertNotNil(request);
}

#pragma mark - bodySize

- (void)testBodySize_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSNumber *result = request.bodySize;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testBodySize_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.bodySize = @1024;

    // -- Assert --
    XCTAssertEqualObjects(request.bodySize, @1024);
}

- (void)testBodySize_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.bodySize = @1024;

    // -- Act --
    request.bodySize = nil;

    // -- Assert --
    XCTAssertNil(request.bodySize);
}

#pragma mark - cookies

- (void)testCookies_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSString *result = request.cookies;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testCookies_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.cookies = @"session=abc123";

    // -- Assert --
    XCTAssertEqualObjects(request.cookies, @"session=abc123");
}

- (void)testCookies_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.cookies = @"session=abc123";

    // -- Act --
    request.cookies = nil;

    // -- Assert --
    XCTAssertNil(request.cookies);
}

#pragma mark - headers

- (void)testHeaders_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSDictionary *result = request.headers;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testHeaders_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.headers = @{ @"Content-Type" : @"application/json" };

    // -- Assert --
    XCTAssertEqualObjects(request.headers[@"Content-Type"], @"application/json");
}

- (void)testHeaders_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.headers = @{ @"Content-Type" : @"application/json" };

    // -- Act --
    request.headers = nil;

    // -- Assert --
    XCTAssertNil(request.headers);
}

#pragma mark - fragment

- (void)testFragment_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSString *result = request.fragment;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testFragment_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.fragment = @"section1";

    // -- Assert --
    XCTAssertEqualObjects(request.fragment, @"section1");
}

- (void)testFragment_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.fragment = @"section1";

    // -- Act --
    request.fragment = nil;

    // -- Assert --
    XCTAssertNil(request.fragment);
}

#pragma mark - method

- (void)testMethod_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSString *result = request.method;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testMethod_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.method = @"POST";

    // -- Assert --
    XCTAssertEqualObjects(request.method, @"POST");
}

- (void)testMethod_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.method = @"POST";

    // -- Act --
    request.method = nil;

    // -- Assert --
    XCTAssertNil(request.method);
}

#pragma mark - queryString

- (void)testQueryString_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSString *result = request.queryString;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testQueryString_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.queryString = @"page=1&limit=10";

    // -- Assert --
    XCTAssertEqualObjects(request.queryString, @"page=1&limit=10");
}

- (void)testQueryString_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.queryString = @"page=1&limit=10";

    // -- Act --
    request.queryString = nil;

    // -- Assert --
    XCTAssertNil(request.queryString);
}

#pragma mark - url

- (void)testUrl_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    NSString *result = request.url;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testUrl_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];

    // -- Act --
    request.url = @"https://example.com/api/test";

    // -- Assert --
    XCTAssertEqualObjects(request.url, @"https://example.com/api/test");
}

- (void)testUrl_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCRequest *request = [[SentryObjCRequest alloc] init];
    request.url = @"https://example.com/api/test";

    // -- Act --
    request.url = nil;

    // -- Assert --
    XCTAssertNil(request.url);
}

@end
