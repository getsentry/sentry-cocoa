#import <XCTest/XCTest.h>
#import "SentryRateLimitParser.h"

@interface SentryRateLimitsParserTests : XCTestCase

@end

/**
* This class exists only for testing SentryRateLimitParser with nil. All other tests are in
* SentryRateLimitsParserTests.swift
*/
@implementation SentryRateLimitsParserTests

- (void)testNil {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    NSDictionary<NSString *, NSDate *> *actual = [SentryRateLimitParser parse:nil];
    #pragma clang diagnostic pop
    
    XCTAssertEqual(0, [actual count]);
}

@end
