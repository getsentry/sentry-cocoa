@import SentryObjC;
@import XCTest;

@interface SentryObjCTraceContextTests : XCTestCase
@end

@implementation SentryObjCTraceContextTests

/// SentryObjCTraceContext has no public initializer, so we verify the class exists and
/// that all readonly property selectors are valid by checking instancesRespondToSelector.

#pragma mark - Class existence

- (void)testClass_shouldExist
{
    // -- Act --
    Class traceContextClass = [SentryObjCTraceContext class];

    // -- Assert --
    XCTAssertTrue(traceContextClass != Nil);
}

#pragma mark - Property selectors

- (void)testTraceId_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(traceId)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testPublicKey_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(publicKey)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testReleaseName_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(releaseName)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testEnvironment_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(environment)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testTransaction_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(transaction)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testSampleRate_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(sampleRate)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testSampleRand_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(sampleRand)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testSampled_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(sampled)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testReplayId_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(replayId)];

    // -- Assert --
    XCTAssertTrue(responds);
}

- (void)testOrgId_selectorShouldExist
{
    // -- Act --
    BOOL responds = [SentryObjCTraceContext instancesRespondToSelector:@selector(orgId)];

    // -- Assert --
    XCTAssertTrue(responds);
}

@end
