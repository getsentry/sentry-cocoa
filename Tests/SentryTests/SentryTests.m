//
//  SentryTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryTests : XCTestCase

@end

@implementation SentryTests

- (void)testVersion {
    NSString *version = [NSString stringWithFormat:@"%@ (%@)", SentryClientVersionString, SentryServerVersionString];
    XCTAssert([version isEqualToString:SentryClient.versionString]);
}

@end
