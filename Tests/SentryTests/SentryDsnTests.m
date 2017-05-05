//
//  SentryDsnTests.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryDsnTests : XCTestCase

@end

@implementation SentryDsnTests

- (void)testDsn {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://sentry.io" didFailWithError:&error];
    XCTAssertEqual(kInvalidDsnError, error.code);
    XCTAssertNil(client);
}

@end
