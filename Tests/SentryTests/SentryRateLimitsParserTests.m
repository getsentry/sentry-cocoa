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
    NSDictionary<NSString* , NSDate* > * actual = [SentryRateLimitParser parse:nil];
    
    XCTAssertEqual(0,  [actual count]);
}

@end
