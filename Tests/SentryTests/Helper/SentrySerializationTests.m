#import "SentrySerialization.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentrySerializationTestss : XCTestCase

@end

/**
 * Actual tests are written in SentrySerializationTests.swift. This class only exists to test
 * passing nil values, which is not possible with Swift cause the compiler avoids it.
 */
@implementation SentrySerializationTestss

- (void)testSentryEnvelopeSerializerWithNilInput
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([SentrySerialization envelopeWithData:nil]);
#pragma clang diagnostic pop
}

@end
