@import XCTest;
#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingSwiftHelpers.h"
#if SWIFT_PACKAGE
#    import "SentrySwift.h"
#else
@import Sentry;
#endif

@interface SentryProfilingSwiftHelpersTests : XCTestCase
@end

@implementation SentryProfilingSwiftHelpersTests

#if SENTRY_PROFILER_TESTS_SUPPORTED

- (void)testStringFromSentryID
{
    SentryId *sentryId = [[SentryId alloc] init];
    XCTAssertEqualObjects(sentryId.sentryIdString, sentry_stringFromSentryID(sentryId));
}

- (void)testGetSentryId
{
    XCTAssertNotNil(sentry_getSentryId());
}

- (void)testGetTraceID
{
    SentryTransactionContext *context =
        [[SentryTransactionContext alloc] initWithTraceId:[[SentryId alloc] init]
                                                   spanId:[[SentrySpanId alloc] init]
                                                 parentId:[[SentrySpanId alloc] init]
                                                operation:@""
                                                  sampled:kSentrySampleDecisionNo];
    XCTAssertEqual(context.traceId, sentry_getTraceID(context));
}

#endif

@end
