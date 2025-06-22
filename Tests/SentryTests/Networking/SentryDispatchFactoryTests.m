#import "SentryDispatchFactory.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>

@interface SentryDispatchFactoryTests : XCTestCase
@property (nonatomic, strong) SentryDispatchFactory *sut;
@end

@implementation SentryDispatchFactoryTests

- (void)setUp
{
    [super setUp];

    self.sut = [[SentryDispatchFactory alloc] init];
}

- (void)testQueueWithNameAndAttributes_shouldReturnQueueWithNameAndAttributesSet
{
    // Note: We are not testing the functionality of the queue itself, just the creation of it,
    // making sure the factory sets the name and attributes correctly.

    // -- Arrange --
    NSString *queueName = @"sentry-dispatch-factory.test";

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithUtilityNamed:queueName];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, [queueName cStringUsingEncoding:NSUTF8StringEncoding]), 0);

    dispatch_qos_class_t actualQoSClass = dispatch_queue_get_qos_class(wrappedQueue.queue, nil);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_UTILITY);
}

- (void)
    testCreateUtilityQueueWithNameAndRelativePriority_shouldReturnQueueWithNameAndRelativePrioritySet
{
    // Note: We are not testing the functionality of the queue itself, just the creation of it,
    // making sure the factory sets the name and attributes correctly.

    // -- Arrange --
    NSString *queueName = @"sentry-dispatch-factory.test";
    int relativePriority = -5;

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue = [self.sut createUtilityQueue:queueName
                                                           relativePriority:relativePriority];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, [queueName cStringUsingEncoding:NSUTF8StringEncoding]), 0);

    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_UTILITY);
    XCTAssertEqual(actualRelativePriority, relativePriority);
}

- (void)testSourceWithInterval_providedEventHandlerIsCalled
{
    // Note: We are not testing the functionality of the source itself, just the creation of it,
    // making sure the factory sets the name and attributes correctly.

    // -- Arrange --
    XCTestExpectation *expectation = [self expectationWithDescription:@"Timer fired"];
    uint64_t interval = 100 * NSEC_PER_MSEC; // 100ms
    uint64_t leeway = 10 * NSEC_PER_MSEC;
    NSString *queueName = @"sentry-dispatch-factory.timer";

    __block int fireCount = 0;
    void (^eventHandler)(void) = ^{
        fireCount++;
        if (fireCount >= 1) {
            [expectation fulfill];
        }
    };

    // -- Act --
    SentryDispatchSourceWrapper *source = [self.sut sourceWithInterval:interval
                                                                leeway:leeway
                                                   concurrentQueueName:queueName
                                                          eventHandler:eventHandler];

    // -- Assert --
    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertGreaterThanOrEqual(fireCount, 1);
    [source cancel];
}

- (void)testSource_queueUsesCorrectQoSAndPriority
{
    // Note: We are not testing the functionality of the source itself, just the creation of it,
    // making sure the factory sets the name and attributes correctly.

    // -- Arrange --
    uint64_t interval = 1000;
    uint64_t leeway = 0;
    NSString *queueName = @"sentry-dispatch-factory.qos-check";
    void (^eventHandler)(void) = ^{ };

    // -- Act --
    SentryDispatchSourceWrapper *source = [self.sut sourceWithInterval:interval
                                                                leeway:leeway
                                                   concurrentQueueName:queueName
                                                          eventHandler:eventHandler];
    SentryDispatchQueueWrapper *queueWrapper = source.queue;

    // -- Assert --
    const char *actualLabel = dispatch_queue_get_label(queueWrapper.queue);
    XCTAssertEqual(strcmp(actualLabel, [queueName cStringUsingEncoding:NSUTF8StringEncoding]), 0);

    dispatch_qos_class_t qos = dispatch_queue_get_qos_class(queueWrapper.queue, nil);
    XCTAssertEqual(qos, QOS_CLASS_UTILITY);
}

@end
