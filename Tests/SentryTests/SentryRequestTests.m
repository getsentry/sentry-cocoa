//
//  SentryRequestTests.m
//  Sentry
//
//  Created by Daniel Griesser on 05/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentryQueueableRequestManager.h"

NSInteger requestShouldReturnCode = 200;

@interface SentryMockNSURLSessionDataTask: NSURLSessionDataTask

@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, copy) void (^completionHandler)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable);

@end

@implementation SentryMockNSURLSessionDataTask

- (instancetype)initWithCompletionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    self = [super init];
    if (self) {
        self.completionHandler = completionHandler;
        self.isCancelled = NO;
    }
    return self;
}

- (void)resume {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isCancelled) {
            if (requestShouldReturnCode != 200) {
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] initWithString:@"https://username:password@app.getsentry.com/12345"] statusCode:requestShouldReturnCode HTTPVersion:nil headerFields:nil];
                self.completionHandler(nil, response, [NSError errorWithDomain:@"" code:requestShouldReturnCode userInfo:nil]);
            } else {
                self.completionHandler(nil, nil, nil);
            }
        }
    });
}

- (void)cancel {
    self.isCancelled = YES;
    self.completionHandler(nil, nil, [NSError errorWithDomain:@"" code:1 userInfo:nil]);
}

@end

@interface SentryMockNSURLSession: NSURLSession

@end

@implementation SentryMockNSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSLog(@"%@", request);
    return [[SentryMockNSURLSessionDataTask alloc] initWithCompletionHandler:completionHandler];
}

@end

@interface SentryMockRequestManager : NSObject <SentryRequestManager>

@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) SentryMockNSURLSession *session;
@property(nonatomic, strong) SentryRequestOperation *lastOperation;

@end

@implementation SentryMockRequestManager

- (instancetype)initWithSession:(SentryMockNSURLSession *)session {
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.sentry.SentryMockRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (BOOL)isReady {
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(_Nullable SentryRequestFinished)completionHandler {
    self.lastOperation = [[SentryRequestOperation alloc] initWithSession:self.session
                                                                                request:request
                                                                      completionHandler:^(NSError * _Nullable error) {
                                                                          [SentryLog logWithMessage:[NSString stringWithFormat:@"Queued requests: %lu", self.queue.operationCount - 1] andLevel:kSentryLogLevelDebug];
                                                                          if (completionHandler) {
                                                                              completionHandler(error);
                                                                          }
                                                                      }];
    [self.queue addOperation:self.lastOperation];
    NSLog(@"%d", self.lastOperation.isAsynchronous);
}

- (void)cancelAllOperations {
    [self.queue cancelAllOperations];
}

- (void)restart {
    [self.lastOperation start];
}

@end

@interface SentryRequestTests : XCTestCase

@property(nonatomic, strong) SentryClient *client;
@property(nonatomic, strong) SentryMockRequestManager *requestManager;
@property(nonatomic, strong) SentryEvent *event;

@end

@implementation SentryRequestTests

- (void)tearDown {
    [super tearDown];
    requestShouldReturnCode = 200;
}

- (void)setUp {
    [super setUp];
    self.requestManager = [[SentryMockRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    self.client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                     requestManager:self.requestManager
                                   didFailWithError:nil];
    self.event = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityDebug];
}

- (void)testRealRequest {
    SentryQueueableRequestManager *requestManager = [[SentryQueueableRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                       requestManager:requestManager
                     didFailWithError:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    [client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRealRequestWithMock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestFailed {
    requestShouldReturnCode = 429;
    
    SentryQueueableRequestManager *requestManager = [[SentryQueueableRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                              requestManager:requestManager
                                            didFailWithError:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueReady {
    SentryQueueableRequestManager *requestManager = [[SentryQueueableRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                              requestManager:requestManager
                                            didFailWithError:nil];
    
    XCTAssertTrue(requestManager.isReady);
    
    [client sendEvent:self.event withCompletionHandler:NULL];
    
    XCTAssertTrue(requestManager.isReady);
    
    for (NSInteger i = 0; i <= 5; i++) {
        [client sendEvent:self.event withCompletionHandler:NULL];
    }
    
    XCTAssertFalse(requestManager.isReady);
}

- (void)testRequestQueueCancel {
    SentryQueueableRequestManager *requestManager = [[SentryQueueableRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"http://a:b@sentry.io/1"
                                              requestManager:requestManager
                                            didFailWithError:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [requestManager cancelAllOperations];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueCancelWithMock {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
    }];
    [self.requestManager cancelAllOperations];
    [self.requestManager restart];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];
    
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event2 = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityInfo];
    [self.client sendEvent:event2 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];
    
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event3 = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityFatal];
    [self.client sendEvent:event3 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];
    
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event4 = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityWarning];
    [self.client sendEvent:event4 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation4 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentFailingEvents {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithMessage:@"bayoom" timestamp:[NSDate date] level:kSentrySeverityError];
    event1.extra = @{@"1": event1};
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

@end
