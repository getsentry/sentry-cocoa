@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionOptionsTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertNotNil(options);
}

#pragma mark - Default values

- (void)testUserInfo_whenDefault_shouldBeTrue
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.userInfo);
}

- (void)testCookies_whenDefault_shouldBeDenyList
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(options.cookies.terms.count, 0u);
}

- (void)testHttpHeaders_whenDefault_shouldBeDenyList
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(
        options.httpHeaders.request.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(
        options.httpHeaders.response.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
}

- (void)testHttpBodies_whenDefault_shouldBeAll
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.httpBodies, SentryObjCDataCollectionHttpBodyTypeAll);
}

- (void)testQueryParams_whenDefault_shouldBeDenyList
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(
        options.queryParams.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
}

- (void)testGraphql_whenDefault_shouldBeTrue
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.graphql.document);
    XCTAssertTrue(options.graphql.variables);
}

- (void)testDatabase_whenDefault_shouldBeTrue
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.database.queryParams);
}

- (void)testStackFrameVariables_whenDefault_shouldBeTrue
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.stackFrameVariables);
}

- (void)testFrameContextLines_whenDefault_shouldBeFive
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.frameContextLines, 5u);
}

#pragma mark - Dictionary Init

- (void)testInitWithDictionary_whenUserInfoIsPresent_shouldSetUserInfo
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"userInfo" : @NO };

    // -- Act --
    SentryObjCDataCollectionOptions *options =
        [[SentryObjCDataCollectionOptions alloc] initWithDictionary:dictionary];

    // -- Assert --
    XCTAssertFalse(options.userInfo);
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
}

- (void)testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"httpBodies" : @[ @"outgoingRequest", @"incomingResponse" ] };

    // -- Act --
    SentryObjCDataCollectionOptions *options =
        [[SentryObjCDataCollectionOptions alloc] initWithDictionary:dictionary];

    // -- Assert --
    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingRequest);
    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingResponse);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingRequest);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingResponse);
    XCTAssertTrue(options.userInfo);
}

- (void)testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault
{
    // -- Arrange --
    NSDictionary *dictionary = @{ @"userInfo" : NSNull.null };

    // -- Act --
    SentryObjCDataCollectionOptions *options =
        [[SentryObjCDataCollectionOptions alloc] initWithDictionary:dictionary];

    // -- Assert --
    XCTAssertTrue(options.userInfo);
}

#pragma mark - Get/Set

- (void)testUserInfo_whenSetToNo_shouldReturnFalse
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.userInfo = NO;
    XCTAssertFalse(options.userInfo);
}

- (void)testCookies_whenSetToOff_shouldReturnOff
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.cookies = [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
}

- (void)testHttpBodies_whenSetToSubset_shouldReturnSubset
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.httpBodies = SentryObjCDataCollectionHttpBodyTypeOutgoingRequest
        | SentryObjCDataCollectionHttpBodyTypeIncomingResponse;

    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingRequest);
    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingResponse);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingRequest);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingResponse);
}

- (void)testStackFrameVariables_whenSetToNo_shouldReturnFalse
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.stackFrameVariables = NO;
    XCTAssertFalse(options.stackFrameVariables);
}

- (void)testFrameContextLines_whenSetToZero_shouldReturnZero
{
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.frameContextLines = 0;
    XCTAssertEqual(options.frameContextLines, 0u);
}

@end
