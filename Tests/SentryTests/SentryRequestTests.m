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
#import "SentryFileManager.h"
#import "NSDate+Extras.h"
#import "SentryClient+Internal.h"

NSInteger requestShouldReturnCode = 200;
NSInteger requestsSuccessfullyFinished = 0;
NSInteger requestsWithErrors = 0;

@interface SentryClient (Private)

/**
 * Initializes a SentryClient which can be used for sending events to sentry.
 *
 * @param dsn DSN string of sentry
 * @param requestManager Object conforming SentryRequestManager protocol
 * @param error NSError reference object
 * @return SentryClient
 */
- (_Nullable instancetype)initWithDsn:(NSString *)dsn
                       requestManager:(id <SentryRequestManager>)requestManager
                     didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

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
                requestsWithErrors++;
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] initWithString:@"https://username:password@app.getsentry.com/12345"] statusCode:requestShouldReturnCode HTTPVersion:nil headerFields:nil];
                self.completionHandler(nil, response, [NSError errorWithDomain:@"" code:requestShouldReturnCode userInfo:nil]);
            } else {
                requestsSuccessfullyFinished++;
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

    if (request.allHTTPHeaderFields[@"X-TEST"]) {
        if (completionHandler) {
            completionHandler([NSError errorWithDomain:@"" code:9898 userInfo:nil]);
            return;
        }
    }

    self.lastOperation = [[SentryRequestOperation alloc] initWithSession:self.session
                                                                                request:request
                                                                      completionHandler:^(NSError * _Nullable error) {
                                                                          [SentryLog logWithMessage:[NSString stringWithFormat:@"Queued requests: %lu", (unsigned long)(self.queue.operationCount - 1)] andLevel:kSentryLogLevelDebug];
                                                                          if (completionHandler) {
                                                                              completionHandler(error);
                                                                          }
                                                                      }];
    [self.queue addOperation:self.lastOperation];
    // leave this here, we ask for it because NSOperation isAsynchronous
    // because it needs to be overwritten
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

- (void)clearAllFiles {
    NSError *error = nil;
    SentryFileManager *fileManager = [[SentryFileManager alloc] initWithError:&error];
    [fileManager deleteAllStoredEvents];
    [fileManager deleteAllStoredBreadcrumbs];
    [fileManager deleteAllFolders];
}

- (void)tearDown {
    [super tearDown];
    requestShouldReturnCode = 200;
    requestsSuccessfullyFinished = 0;
    requestsWithErrors = 0;
    [self.client clearContext];
    [self clearAllFiles];
}

- (void)setUp {
    [super setUp];
    [self clearAllFiles];
    self.requestManager = [[SentryMockRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    self.client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                     requestManager:self.requestManager
                                   didFailWithError:nil];
    self.event = [[SentryEvent alloc] initWithLevel:kSentrySeverityDebug];
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

    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should fail"];
    [self.client sendEvent:self.event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testRequestFailedSerialization {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    event1.extra = @{@"a": event1};
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

- (void)testRequestQueueReady {
    SentryQueueableRequestManager *requestManager = [[SentryQueueableRequestManager alloc] initWithSession:[SentryMockNSURLSession new]];
    SentryClient *client = [[SentryClient alloc] initWithDsn:@"https://username:password@app.getsentry.com/12345"
                                              requestManager:requestManager
                                            didFailWithError:nil];

    XCTAssertTrue(requestManager.isReady);

    [client sendEvent:self.event withCompletionHandler:NULL];

    for (NSInteger i = 0; i <= 5; i++) {
        [client sendEvent:self.event withCompletionHandler:NULL];
    }

    XCTAssertFalse(requestManager.isReady);
}

- (void)testRequestQueueCancel {
    SentryClient.logLevel = kSentryLogLevelVerbose;
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
    SentryClient.logLevel = kSentryLogLevelError;
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

- (void)testRequestQueueWithDifferentEvents1 {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents2 {
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Request should finish2"];
    SentryEvent *event2 = [[SentryEvent alloc] initWithLevel:kSentrySeverityInfo];
    [self.client sendEvent:event2 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents3 {
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Request should finish3"];
    SentryEvent *event3 = [[SentryEvent alloc] initWithLevel:kSentrySeverityFatal];
    [self.client sendEvent:event3 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentEvents4 {
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Request should finish4"];
    SentryEvent *event4 = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
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

- (void)testRequestQueueMultipleEvents {
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish1"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];

    XCTestExpectation *expectation4 = [self expectationWithDescription:@"Request should finish4"];
    SentryEvent *event4 = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
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

- (void)testUseClientProperties {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    self.client.user = [[SentryUser alloc] initWithUserId:@"XXXXXX"];
    NSDate *date = [NSDate date];
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    crumb.timestamp = date;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        SentryContext *context = [[SentryContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date sentry_toIso8601String]
                                                            }
                                                        ],
                                     @"user": @{@"id": @"XXXXXX"},
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"d"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"sentry-cocoa", @"version": SentryClient.versionString},
                                     @"tags": @{@"a": @"b"},
                                     @"timestamp": [date sentry_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testUseClientPropertiesMerge {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    NSDate *date = [NSDate date];
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.timestamp = date;
    event.tags = @{@"1": @"2"};
    event.extra = @{@"3": @"4"};
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        SentryContext *context = [[SentryContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date sentry_toIso8601String]
                                                            }
                                                        ],
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"d", @"3": @"4"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"sentry-cocoa", @"version": SentryClient.versionString},
                                     @"tags": @{@"a": @"b", @"1": @"2"},
                                     @"timestamp": [date sentry_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}


- (void)testEventPropsAreStrongerThanClientProperties {
    self.client.tags = @{@"a": @"b"};
    self.client.extra = @{@"c": @"d"};
    NSDate *date = [NSDate date];
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentrySeverityInfo category:@"you"];
    crumb.timestamp = date;
    [self.client.breadcrumbs addBreadcrumb:crumb];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish4"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.infoDict = @{@"CFBundleIdentifier": @"a", @"CFBundleShortVersionString": @"b", @"CFBundleVersion": @"c"};
    event.timestamp = date;
    event.tags = @{@"a": @"1"};
    event.extra = @{@"c": @"2"};
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        SentryContext *context = [[SentryContext alloc] init];
        NSDictionary *serialized = @{@"breadcrumbs": @[ @{
                                                            @"category": @"you",
                                                            @"level": @"info",
                                                            @"timestamp": [date sentry_toIso8601String]
                                                            }
                                                        ],
                                     @"contexts": [context serialize],
                                     @"event_id": event.eventId,
                                     @"extra": @{@"c": @"2"},
                                     @"level": @"warning",
                                     @"platform": @"cocoa",
                                     @"release": @"a-b",
                                     @"dist": @"c",
                                     @"sdk": @{@"name": @"sentry-cocoa", @"version": SentryClient.versionString},
                                     @"tags": @{@"a": @"1"},
                                     @"timestamp": [date sentry_toIso8601String]};
        XCTAssertEqualObjects([self.client.lastEvent serialize], serialized);
        [self.client.breadcrumbs clear];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testRequestQueueWithDifferentFailingEvents {
    requestShouldReturnCode = 429;
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event1 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    [self.client sendEvent:event1 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        [expectation1 fulfill];
    }];

    [self waitForExpectations:@[expectation1] timeout:5];
    XCTAssertEqual(requestsWithErrors, 1);
    requestShouldReturnCode = 200;

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event2 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    [self.client sendEvent:event2 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation2 fulfill];
    }];

    [self waitForExpectations:@[expectation2] timeout:5];
    XCTAssertEqual(requestsSuccessfullyFinished, 1);
    XCTAssertEqual(requestsWithErrors, 1);
    requestShouldReturnCode = 200;

    XCTestExpectation *expectation3 = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event3 = [[SentryEvent alloc] initWithLevel:kSentrySeverityError];
    [self.client sendEvent:event3 withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation3 fulfill];
    }];

    [self waitForExpectations:@[expectation3] timeout:5];
    XCTAssertEqual(requestsSuccessfullyFinished, 3);
}

- (void)testBlockBeforeSerializeEvent {
    NSDictionary *tags = @{@"a": @"b"};
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    self.client.beforeSerializeEvent = ^(SentryEvent * _Nonnull event) {
        event.tags = tags;
    };
    XCTAssertNil(event.tags);
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertEqualObjects(self.client.lastEvent.tags, tags);
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

- (void)testBlockBeforeSendRequest {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    self.client.beforeSendRequest = ^(SentryNSURLRequest * _Nonnull request) {
        [request setValue:@"12345" forHTTPHeaderField:@"X-TEST"];
    };

    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 9898);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"waitForExpectationsWithTimeout errored");
        }
        XCTAssert(YES);
    }];
}

- (void)testSnapshotStacktrace {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    
    SentryThread *thread = [[SentryThread alloc] initWithThreadId:@(9999)];
    self.client._snapshotThreads = @[thread];
    self.client._debugMeta = @[[[SentryDebugMeta alloc] init]];
    
    [self.client snapshotStacktrace:^{
        [self.client appendStacktraceToEvent:event];
        XCTAssertTrue(YES);
    }];
    
    __weak id weakSelf = self;
    self.client.beforeSerializeEvent = ^(SentryEvent * _Nonnull event) {
        id self = weakSelf;
        XCTAssertEqualObjects(event.threads.firstObject.threadId, @(9999));
        XCTAssertNotNil(event.debugMeta);
        XCTAssertTrue(event.debugMeta.count > 0);
    };
    
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testShouldSendEventNo {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"abc";
    __weak id weakSelf = self;
    self.client.shouldSendEvent = ^BOOL(SentryEvent * _Nonnull event) {
        id self = weakSelf;
        if ([event.message isEqualToString:@"abc"]) {
            XCTAssertTrue(YES);
        } else {
            XCTAssertTrue(NO);
        }
        return NO;
    };
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testShouldSendEventYes {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"abc";
    __weak id weakSelf = self;
    self.client.shouldSendEvent = ^BOOL(SentryEvent * _Nonnull event) {
        id self = weakSelf;
        if ([event.message isEqualToString:@"abc"]) {
            XCTAssertTrue(YES);
        } else {
            XCTAssertTrue(NO);
        }
        return YES;
    };
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testSamplingZero {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = 0.0;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testSamplingOne {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = 1.0;
    XCTAssertEqual(self.client.sampleRate, 1.0);
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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

- (void)testSamplingBogus {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Request should finish"];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentrySeverityWarning];
    event.message = @"abc";
    self.client.sampleRate = -123.0;
    [self.client sendEvent:event withCompletionHandler:^(NSError * _Nullable error) {
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



@end
