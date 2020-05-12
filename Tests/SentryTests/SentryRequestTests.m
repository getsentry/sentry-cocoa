#import "NSDate+SentryExtras.h"
#import "SentryClient.h"
#import "SentryDsn.h"
#import "SentryFileManager.h"
#import "SentryLog.h"
#import "SentryQueueableRequestManager.h"
#import "SentryRequestOperation.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

NSInteger requestShouldReturnCode = 200;
NSString *dsn = @"https://username:password@app.getsentry.com/12345";

@interface SentryClient (Private)

- (_Nullable instancetype)
     initWithOptions:(NSDictionary<NSString *, id> *)options
      requestManager:(id<SentryRequestManager>)requestManager
    didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

@interface SentryMockNSURLSessionDataTask : NSURLSessionDataTask

@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, copy) void (^completionHandler)
    (NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable);

@end

@implementation SentryMockNSURLSessionDataTask

- (instancetype)initWithCompletionHandler:
    (void (^)(NSData *_Nullable, NSURLResponse *_Nullable,
        NSError *_Nullable))completionHandler
{
    self = [super init];
    if (self) {
        self.completionHandler = completionHandler;
        self.isCancelled = NO;
    }
    return self;
}

- (void)resume
{
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            if (!self.isCancelled) {
                NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]
                     initWithURL:[[NSURL alloc] initWithString:dsn]
                      statusCode:requestShouldReturnCode
                     HTTPVersion:nil
                    headerFields:nil];
                if (requestShouldReturnCode != 200) {
                    self.completionHandler(nil, response,
                        [NSError errorWithDomain:@""
                                            code:requestShouldReturnCode
                                        userInfo:nil]);
                } else {
                    self.completionHandler(nil, response, nil);
                }
            }
        });
}

- (void)cancel
{
    self.isCancelled = YES;
    self.completionHandler(
        nil, nil, [NSError errorWithDomain:@"" code:1 userInfo:nil]);
}

@end

@interface SentryMockNSURLSession : NSURLSession

@end

@implementation SentryMockNSURLSession

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
- (NSURLSessionDataTask *)
    dataTaskWithRequest:(NSURLRequest *)request
      completionHandler:(void (^)(NSData *_Nullable, NSURLResponse *_Nullable,
                            NSError *_Nullable))completionHandler
{
    return [[SentryMockNSURLSessionDataTask alloc]
        initWithCompletionHandler:completionHandler];
}
#pragma GCC diagnostic pop

@end

@interface SentryMockRequestManager : NSObject <SentryRequestManager>

@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) SentryMockNSURLSession *session;
@property (nonatomic, strong) SentryRequestOperation *lastOperation;
@property (nonatomic, assign) NSInteger requestsSuccessfullyFinished;
@property (nonatomic, assign) NSInteger requestsWithErrors;

@end

@implementation SentryMockRequestManager

- (instancetype)initWithSession:(SentryMockNSURLSession *)session
{
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.sentry.SentryMockRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
        self.requestsWithErrors = 0;
        self.requestsSuccessfullyFinished = 0;
    }
    return self;
}

- (BOOL)isReady
{
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request
    completionHandler:
        (_Nullable SentryRequestOperationFinished)completionHandler
{
    if (request.allHTTPHeaderFields[@"X-TEST"]) {
        if (completionHandler) {
            completionHandler(
                nil, [NSError errorWithDomain:@"" code:9898 userInfo:nil]);
            return;
        }
    }

    self.lastOperation = [[SentryRequestOperation alloc]
          initWithSession:self.session
                  request:request
        completionHandler:^(
            NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            [SentryLog
                logWithMessage:[NSString
                                   stringWithFormat:@"Queued requests: %lu",
                                   (unsigned long)(self.queue.operationCount
                                       - 1)]
                      andLevel:kSentryLogLevelDebug];
            if ([response statusCode] != 200) {
                self.requestsWithErrors++;
            } else {
                self.requestsSuccessfullyFinished++;
            }
            if (completionHandler) {
                completionHandler(response, error);
            }
        }];
    [self.queue addOperation:self.lastOperation];
    // leave this here, we ask for it because NSOperation isAsynchronous
    // because it needs to be overwritten
    NSLog(@"%d", self.lastOperation.isAsynchronous);
}

- (void)cancelAllOperations
{
    [self.queue cancelAllOperations];
}

- (void)restart
{
    [self.lastOperation start];
}

@end

@interface SentryRequestTests : XCTestCase

@property (nonatomic, strong) SentryClient *client;
@property (nonatomic, strong) SentryMockRequestManager *requestManager;
@property (nonatomic, strong) SentryEvent *event;

@end

@implementation SentryRequestTests

- (void)clearAllFiles
{
    NSError *error = nil;
    SentryFileManager *fileManager = [[SentryFileManager alloc]
             initWithDsn:[[SentryDsn alloc] initWithString:dsn
                                          didFailWithError:nil]
        didFailWithError:&error];
    [fileManager deleteAllStoredEventsAndEnvelopes];
    [fileManager deleteAllFolders];
}

- (void)tearDown
{
    [super tearDown];
    requestShouldReturnCode = 200;
    // TODO(fetzig) reaplaced this with `bindClient:nil` but should reset scope
    // as well. check how.
    //[self.client clearContext];
    [SentrySDK.currentHub bindClient:nil];
    [self clearAllFiles];
    [self.requestManager cancelAllOperations];
}

- (void)setUp
{
    [super setUp];
    [self clearAllFiles];
    self.requestManager = [[SentryMockRequestManager alloc]
        initWithSession:[SentryMockNSURLSession new]];
    self.client = [[SentryClient alloc] initWithOptions:@{ @"dsn" : dsn }
                                         requestManager:self.requestManager
                                       didFailWithError:nil];
    self.event = [[SentryEvent alloc] initWithLevel:kSentryLevelDebug];
}

- (XCTestExpectation *)waitUntilLocalFileQueueIsFlushed:
    (SentryFileManager *)fileManager
{
    XCTestExpectation *expectation =
        [self expectationWithDescription:@"wait for file queue"];
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSInteger i = 0; i <= 100; i++) {
                NSLog(@"@@ %lu",
                    (unsigned long)[fileManager getAllStoredEventsAndEnvelopes]
                        .count);
                if ([fileManager getAllStoredEventsAndEnvelopes].count == 0) {
                    [expectation fulfill];
                    return;
                }
                sleep(1);
            }
        });
    return expectation;
}

@end
