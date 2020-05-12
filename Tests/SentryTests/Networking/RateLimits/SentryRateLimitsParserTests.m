#import "SentryRateLimitParser.h"
#import <XCTest/XCTest.h>

@interface SentryRateLimitsParserTests : XCTestCase

@end

/**
 * This class exists only for testing SentryRateLimitParser with nil. All other
 * tests are in SentryRateLimitsParserTests.swift
 */
@implementation SentryRateLimitsParserTests

- (void)testNil
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    SentryRateLimitParser *sut = [[SentryRateLimitParser alloc] init];
    NSDictionary<NSString *, NSDate *> *actual = [sut parse:nil];
#pragma clang diagnostic pop

    XCTAssertEqual(0, [actual count]);
}

@end
