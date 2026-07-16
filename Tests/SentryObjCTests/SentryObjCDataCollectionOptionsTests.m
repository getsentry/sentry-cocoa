@import SentryObjC;
@import XCTest;

@interface SentryObjCDataCollectionOptionsTests : XCTestCase
@end

@implementation SentryObjCDataCollectionOptionsTests

#pragma mark - Init

- (void)testInit_shouldCreateInstance
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertNotNil(options);
#endif
}

#pragma mark - Default values

- (void)testUserInfo_whenDefault_shouldBeTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.userInfo);
#endif
}

- (void)testCookies_whenDefault_shouldBeDenyList
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(options.cookies.terms.count, 0u);
#endif
}

- (void)testHttpHeaders_whenDefault_shouldBeDenyList
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(
        options.httpHeaders.request.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
    XCTAssertEqual(
        options.httpHeaders.response.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
#endif
}

- (void)testHttpBodies_whenDefault_shouldBeAll
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.httpBodies, SentryObjCDataCollectionHttpBodyTypeAll);
#endif
}

- (void)testQueryParams_whenDefault_shouldBeDenyList
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(
        options.queryParams.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
#endif
}

- (void)testGraphql_whenDefault_shouldBeTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.graphql.document);
    XCTAssertTrue(options.graphql.variables);
#endif
}

- (void)testDatabase_whenDefault_shouldBeTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.database.queryParams);
#endif
}

- (void)testStackFrameVariables_whenDefault_shouldBeTrue
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertTrue(options.stackFrameVariables);
#endif
}

- (void)testFrameContextLines_whenDefault_shouldBeFive
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    XCTAssertEqual(options.frameContextLines, 5u);
#endif
}

#pragma mark - Dictionary Init

- (void)testInitWithDictionary_whenUserInfoIsPresent_shouldSetUserInfo
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    NSDictionary *dictionary = @{ @"userInfo" : @NO };

    // -- Act --
    SentryObjCDataCollectionOptions *options =
        [[SentryObjCDataCollectionOptions alloc] initWithDictionary:dictionary];

    // -- Assert --
    XCTAssertFalse(options.userInfo);
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeDenyList);
#endif
}

- (void)testInitWithDictionary_whenHttpBodiesIsPresent_shouldSetHttpBodies
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
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
#endif
}

- (void)testInitWithDictionary_whenUserInfoIsNSNull_shouldUseDefault
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    // -- Arrange --
    NSDictionary *dictionary = @{ @"userInfo" : NSNull.null };

    // -- Act --
    SentryObjCDataCollectionOptions *options =
        [[SentryObjCDataCollectionOptions alloc] initWithDictionary:dictionary];

    // -- Assert --
    XCTAssertTrue(options.userInfo);
#endif
}

#pragma mark - Get/Set

- (void)testUserInfo_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.userInfo = NO;
    XCTAssertFalse(options.userInfo);
#endif
}

- (void)testCookies_whenSetToOff_shouldReturnOff
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.cookies = [SentryObjCDataCollectionKeyValueCollectionBehavior off];
    XCTAssertEqual(options.cookies.mode, SentryObjCDataCollectionKeyValueCollectionModeOff);
#endif
}

- (void)testHttpBodies_whenSetToSubset_shouldReturnSubset
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.httpBodies = SentryObjCDataCollectionHttpBodyTypeOutgoingRequest
        | SentryObjCDataCollectionHttpBodyTypeIncomingResponse;

    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingRequest);
    XCTAssertTrue(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingResponse);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeIncomingRequest);
    XCTAssertFalse(options.httpBodies & SentryObjCDataCollectionHttpBodyTypeOutgoingResponse);
#endif
}

- (void)testStackFrameVariables_whenSetToNo_shouldReturnFalse
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.stackFrameVariables = NO;
    XCTAssertFalse(options.stackFrameVariables);
#endif
}

- (void)testFrameContextLines_whenSetToZero_shouldReturnZero
{
#if !SDK_V10
    XCTSkip(@"Test skipped for SDK_V10");
#else
    SentryObjCDataCollectionOptions *options = [[SentryObjCDataCollectionOptions alloc] init];
    options.frameContextLines = 0;
    XCTAssertEqual(options.frameContextLines, 0u);
#endif
}

@end
