#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDispatchSourceWrapper.h"
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
    const char *queueName = "sentry-dispatch-factory.test";
    int relativePriority = -5;
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, relativePriority);

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue = [self.sut queueWithName:queueName
                                                            attributes:attributes];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, queueName), 0);

    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_BACKGROUND);
    XCTAssertEqual(actualRelativePriority, relativePriority);
}

- (void)
    testCreateBackgroundQueueWithNameAndRelativePriority_shouldReturnQueueWithNameAndRelativePrioritySet
{
    // Note: We are not testing the functionality of the queue itself, just the creation of it,
    // making sure the factory sets the name and attributes correctly.

    // -- Arrange --
    const char *queueName = "sentry-dispatch-factory.test";
    int relativePriority = -5;

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [self.sut createBackgroundQueueWithName:queueName relativePriority:relativePriority];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, queueName), 0);

    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_BACKGROUND);
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
    const char *queueName = "sentry-dispatch-factory.timer";
    dispatch_queue_attr_t attributes
        = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);

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
                                                             queueName:queueName
                                                            attributes:attributes
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
    const char *queueName = "sentry-dispatch-factory.qos-check";
    dispatch_queue_attr_t attributes
        = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, -10);
    void (^eventHandler)(void) = ^{ };

    // -- Act --
    SentryDispatchSourceWrapper *source = [self.sut sourceWithInterval:interval
                                                                leeway:leeway
                                                             queueName:queueName
                                                            attributes:attributes
                                                          eventHandler:eventHandler];
    SentryDispatchQueueWrapper *queueWrapper = source.queue;

    // -- Assert --
    const char *actualLabel = dispatch_queue_get_label(queueWrapper.queue);
    XCTAssertEqual(strcmp(actualLabel, queueName), 0);

    int relativePriority;
    dispatch_qos_class_t qos = dispatch_queue_get_qos_class(queueWrapper.queue, &relativePriority);
    XCTAssertEqual(qos, QOS_CLASS_BACKGROUND);
    XCTAssertEqual(relativePriority, -10);
}

@end
