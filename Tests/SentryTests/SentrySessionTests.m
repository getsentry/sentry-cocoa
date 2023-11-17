#import "SentrySession.h"
#import <XCTest/XCTest.h>

@interface SentrySessionTests : XCTestCase

@end

@implementation SentrySessionTests

- (void)testInitDefaultValues
{
    SentrySession *session = [[SentrySession alloc] initWithReleaseName:@"1.0.0" distinctId:@"some-id"];
    XCTAssertNotNil(session.sessionId);
    XCTAssertEqual(1, session.sequence);
    XCTAssertEqual(0, session.errors);
    XCTAssertTrue(session.flagInit);
    XCTAssertNotNil(session.started);
    XCTAssertEqual(kSentrySessionStatusOk, session.status);
    XCTAssertNotNil(session.distinctId);

    XCTAssertNil(session.timestamp);
    XCTAssertEqual(@"1.0.0", session.releaseName);
    XCTAssertNil(session.environment);
    XCTAssertNil(session.duration);
}

- (void)testSerializeDefaultValues
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"1.0.0" distinctId:@"some-id"];
    NSDictionary<NSString *, id> *json = [expected serialize];
    SentrySession *actual = [[SentrySession alloc] initWithJSONObject:json];

    XCTAssertTrue([expected.sessionId isEqual:actual.sessionId]);
    XCTAssertEqual(expected.sequence, actual.sequence);
    XCTAssertEqual(expected.errors, actual.errors);

    XCTAssertEqualWithAccuracy([expected.started timeIntervalSinceReferenceDate],
        [actual.started timeIntervalSinceReferenceDate], 1);
    XCTAssertEqual(expected.status, actual.status);
    XCTAssertEqual(expected.distinctId, actual.distinctId);
    XCTAssertNil(expected.timestamp);
    // Serialize session always have a timestamp (time of serialization)
    XCTAssertNotNil(actual.timestamp);
    XCTAssertEqual(@"1.0.0", expected.releaseName);
    XCTAssertEqual(@"1.0.0", actual.releaseName);
    XCTAssertNil(expected.environment);
    XCTAssertNil(actual.environment);
    XCTAssertNil(expected.duration);
    XCTAssertNil(actual.duration);
}

- (void)testSerializeExtraFieldsEndedSessionWithNilStatus
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"io.sentry@5.0.0-test" distinctId:@"some-id"];
    NSDate *timestamp = [NSDate date];
    [expected endSessionExitedWithTimestamp:timestamp];
    expected.environment = @"prod";
    NSDictionary<NSString *, id> *json = [expected serialize];
    SentrySession *actual = [[SentrySession alloc] initWithJSONObject:json];

    XCTAssertTrue([expected.sessionId isEqual:actual.sessionId]);
    XCTAssertEqual(expected.sequence, actual.sequence);
    XCTAssertEqual(expected.errors, actual.errors);

    XCTAssertEqualWithAccuracy([expected.started timeIntervalSinceReferenceDate],
        [actual.started timeIntervalSinceReferenceDate], 1);
    XCTAssertEqualWithAccuracy([timestamp timeIntervalSinceReferenceDate],
        [expected.timestamp timeIntervalSinceReferenceDate], 1);
    XCTAssertEqualWithAccuracy([expected.timestamp timeIntervalSinceReferenceDate],
        [actual.timestamp timeIntervalSinceReferenceDate], 1);
    XCTAssertEqual(expected.status, actual.status);
    XCTAssertEqual(expected.distinctId, actual.distinctId);
    XCTAssertEqual(expected.releaseName, actual.releaseName);
    XCTAssertEqual(expected.environment, actual.environment);
    XCTAssertEqual(expected.duration, actual.duration);
}

- (void)testSerializeErrorIncremented
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"" distinctId:@"some-id"];
    [expected incrementErrors];
    [expected endSessionExitedWithTimestamp:[NSDate date]];
    NSDictionary<NSString *, id> *json = [expected serialize];
    SentrySession *actual = [[SentrySession alloc] initWithJSONObject:json];

    XCTAssertTrue([expected.sessionId isEqual:actual.sessionId]);
    XCTAssertEqual(expected.sequence, actual.sequence);
    XCTAssertEqual(expected.errors, actual.errors);

    XCTAssertEqualWithAccuracy([expected.started timeIntervalSinceReferenceDate],
        [actual.started timeIntervalSinceReferenceDate], 1);
    XCTAssertEqualWithAccuracy([expected.timestamp timeIntervalSinceReferenceDate],
        [actual.timestamp timeIntervalSinceReferenceDate], 1);
    XCTAssertEqual(expected.status, actual.status);
    XCTAssertEqual(expected.distinctId, actual.distinctId);
    XCTAssertEqual(expected.releaseName, actual.releaseName);
    XCTAssertEqual(expected.environment, actual.environment);
    XCTAssertEqual(expected.duration, actual.duration);
}

- (void)testAbnormalSession
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"" distinctId:@"some-id"];
    XCTAssertEqual(0, expected.errors);
    XCTAssertEqual(kSentrySessionStatusOk, expected.status);
    XCTAssertEqual(1, expected.sequence);
    [expected incrementErrors];
    XCTAssertEqual(1, expected.errors);
    XCTAssertEqual(kSentrySessionStatusOk, expected.status);
    XCTAssertEqual(2, expected.sequence);
    [expected endSessionAbnormalWithTimestamp:[NSDate date]];
    XCTAssertEqual(1, expected.errors);
    XCTAssertEqual(kSentrySessionStatusAbnormal, expected.status);
    XCTAssertEqual(3, expected.sequence);
}

- (void)testCrashedSession
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"" distinctId:@"some-id"];
    XCTAssertEqual(1, expected.sequence);
    XCTAssertEqual(kSentrySessionStatusOk, expected.status);
    [expected endSessionCrashedWithTimestamp:[NSDate date]];
    XCTAssertEqual(kSentrySessionStatusCrashed, expected.status);
    XCTAssertEqual(2, expected.sequence);
}

- (void)testExitedSession
{
    SentrySession *expected = [[SentrySession alloc] initWithReleaseName:@"" distinctId:@"some-id"];
    XCTAssertEqual(0, expected.errors);
    XCTAssertEqual(kSentrySessionStatusOk, expected.status);
    XCTAssertEqual(1, expected.sequence);
    [expected endSessionExitedWithTimestamp:[NSDate date]];
    XCTAssertEqual(0, expected.errors);
    XCTAssertEqual(kSentrySessionStatusExited, expected.status);
    XCTAssertEqual(2, expected.sequence);
}

@end
