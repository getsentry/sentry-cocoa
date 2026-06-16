@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalEnvelopeApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalEnvelopeApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - Accessor

- (void)testInternal_envelope_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalEnvelopeApi *envelope = SentryObjCSDK.internal.envelope;

    // -- Assert --
    XCTAssertNotNil(envelope);
}

#pragma mark - deserializeFrom

- (void)testDeserializeFrom_whenEmptyData_shouldReturnNil
{
    // -- Act --
    SentryObjCEnvelope *result = [SentryObjCSDK.internal.envelope deserializeFrom:[NSData data]];

    // -- Assert --
    XCTAssertNil(result);
}

@end
