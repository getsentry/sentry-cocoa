#import <XCTest/XCTest.h>
#import "SentryEnvelopeRateLimit.h"
#import "SentryTests-Bridging-Header.h"

@interface SentryEnvelopeRateLimitTests : XCTestCase

@end

/**
* This class exists only for testing SentryEnvelopeRateLimitTests with nil. All other tests are in
* SentryEnvelopeRateLimitTests.swift
*/
@implementation SentryEnvelopeRateLimitTests

- (void)testNil {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    SentryEnvelopeRateLimit *sut = [[SentryEnvelopeRateLimit alloc] initWithRateLimits:nil];
    XCTAssertNil([sut removeRateLimitedItems:nil]);
    #pragma clang diagnostic pop
}

@end
