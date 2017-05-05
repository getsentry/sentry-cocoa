//
//  SentryRequestTests.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>

@interface SentryMockRequestManager : NSObject <SentryRequestManager>

@property(nonatomic, retain) NSMutableArray *queue;

@end

@implementation SentryMockRequestManager

- (instancetype)initWithSession:(NSURLSession *)session {
    self = [super init];
    if (self) {
    }
    return self;
}

- (BOOL)isReady {
    return self.queue.count <= 1;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(SentryQueueableRequestManagerHandler)completionHandler {
    [self.queue addObject:request];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.queue removeObject:request];
        completionHandler(nil);
    });
}

@end

@interface SentryRequestTests : XCTestCase

@property(nonatomic, retain) SentryClient *client;

@end

@implementation SentryRequestTests

- (void)setUp {
    [super setUp];
    SentryMockRequestManager *requestManager = [[SentryMockRequestManager alloc] init];
    self.client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                     requestManager:requestManager
                                   didFailWithError:nil];
}

- (void)testAddRequests {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    [self.client sendEventWithCompletionHandler:^(NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
    }];
}


@end
