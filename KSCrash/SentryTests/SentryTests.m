//
//  SentryTests.m
//  SentryTests
//
//  Created by Daniel Griesser on 04.09.17.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryClient+Internal.h"


@interface SentryTests : XCTestCase
@property(nonatomic, strong) SentryClient *client;
@end

@implementation SentryTests

- (void)setUp {
    [super setUp];
    NSError *error = nil;
    self.client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345" didFailWithError:&error];
    [self.client startCrashHandlerWithError:&error];
    SentryClient.sharedClient = self.client;
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testKSCrashConvert {
    XCTestExpectation *expectation = [self expectationWithDescription:@"snapshotStacktrace"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];

    [self.client snapshotStacktrace:^{
        [self.client appendStacktraceToEvent:event];
        XCTAssertNotNil(event.threads.firstObject.stacktrace);
        XCTAssertNotNil(event.debugMeta);
        XCTAssertTrue(event.debugMeta.count > 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

@end
