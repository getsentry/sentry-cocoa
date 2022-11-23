#import "SentryTests-Swift.h"
#import <Sentry/Sentry.h>
#import <XCTest/XCTest.h>

@interface SentryCoreDataTrackerObjcTests : XCTestCase

@end

@implementation SentryCoreDataTrackerObjcTests {
    TestNSManagedObjectContext *context;
}

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [TestCleanup clearTestState];
    [super tearDown];
}

- (void)test_requestWithErrorPointer_noError
{
    TestNSManagedObjectContext *context = [[TestNSManagedObjectContext alloc] init];
    SentryCoreDataTracker *dataTracker = [[SentryCoreDataTracker alloc] init];

    SentryTracer *tracer = [SentrySDK startTransactionWithName:@"TestTransaction"
                                                     operation:@"TestTransactionOperation"
                                                   bindToScope:true];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"TestEntity"];
    NSError *error;
    NSArray *result =
        [dataTracker managedObjectContext:context
                      executeFetchRequest:fetchRequest
                                    error:&error
                              originalImp:^NSArray *(
                                  __unused NSFetchRequest *req, __unused NSError **internalError) {
                                  return [[NSArray alloc] initWithObjects:@"One Object", nil];
                              }];

    SentrySpan *span = tracer.children.firstObject;

    XCTAssertEqual(span.context.status, kSentrySpanStatusOk);

    XCTAssertEqual(result.count, 1);
}

- (void)test_requestWithErrorPointer_WithError
{
    TestNSManagedObjectContext *context = [[TestNSManagedObjectContext alloc] init];
    SentryCoreDataTracker *dataTracker = [[SentryCoreDataTracker alloc] init];

    SentryTracer *tracer = [SentrySDK startTransactionWithName:@"TestTransaction"
                                                     operation:@"TestTransactionOperation"
                                                   bindToScope:true];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"TestEntity"];
    NSError *error;
    __unused NSArray *result =
        [dataTracker managedObjectContext:context
                      executeFetchRequest:fetchRequest
                                    error:&error
                              originalImp:^NSArray *(
                                  __unused NSFetchRequest *req, __unused NSError **internalError) {
                                  *internalError = [[NSError alloc] init];
                                  return nil;
                              }];

    SentrySpan *span = tracer.children.firstObject;
    XCTAssertEqual(span.context.status, kSentrySpanStatusInternalError);
}

@end
