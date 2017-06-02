//
//  SentryDsnTests.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryError.h"

@interface SentryDsnTests : XCTestCase

@end

@implementation SentryDsnTests

- (void)testMissingUsernamePassword {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://sentry.io" didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testMissingScheme {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"sentry.io" didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testMissingHost {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"http:///1" didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

- (void)testUnsupportedProtocol {
    NSError *error = nil;
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"ftp://sentry.io/1" didFailWithError:&error];
    XCTAssertEqual(kSentryErrorInvalidDsnError, error.code);
    XCTAssertNil(client);
}

@end
