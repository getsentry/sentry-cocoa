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

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVersion {
    NSString *version = [NSString stringWithFormat:@"%@ (%@)", SentryClientVersionString, SentryServerVersionString];
    XCTAssert([version isEqualToString:SentryClient.versionString]);
}

- (void)testDsn {
    NSError *error = nil;
    [[SentryClient alloc] initWithDsn:@"https://sentry.io" didFailWithError:&error];
    XCTAssertEqual(kInvalidDSNError, error.code);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
