#import "SentrySerialization.h"
#import <XCTest/XCTest.h>

@interface SentrySerializationNilTests : XCTestCase

@end

/**
 * Actual tests are written in SentrySerializationTests.swift. This class only exists to test
 * passing nil values, which is not possible with Swift cause the compiler avoids it.
 */
@implementation SentrySerializationNilTests

- (void)testSentryEnvelopeSerializerWithNilInput
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([SentrySerialization envelopeWithData:nil]);
#pragma clang diagnostic pop
}

@end
