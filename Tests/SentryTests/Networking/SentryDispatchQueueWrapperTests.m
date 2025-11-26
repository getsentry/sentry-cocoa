#import "SentrySwift.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDispatchQueueWrapperTests : XCTestCase

@end

@implementation SentryDispatchQueueWrapperTests

- (void)testInitWithNameAndAttributes_shouldCreateQueueWithName
{
    // -- Arrange --
    const char *queueName = "sentry-dispatch-factory.test";

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:queueName
                                              attributes:DISPATCH_QUEUE_SERIAL];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, queueName), 0);
}

- (void)testInitWithNameAndAttributes_customAttributes_shouldCreateQueueWithGivenAttributes
{
    // -- Arrange --
    const char *queueName = "sentry-dispatch-factory.test";
    int relativePriority = -5;
    qos_class_t qosClass = QOS_CLASS_UTILITY;
    dispatch_queue_attr_t _Nullable attr = DISPATCH_QUEUE_SERIAL;

    dispatch_queue_attr_t _Nullable attributes
        = dispatch_queue_attr_make_with_qos_class(attr, qosClass, relativePriority);

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:queueName attributes:attributes];

    // -- Assert --
    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_UTILITY);
    XCTAssertEqual(actualRelativePriority, -5);
}

- (void)
    testInitWithNameAndAttributes_customAttributesWithPositiveRelativePriority_shouldCreateQueueWithUnspecifiedQoS
{
    // The relative priority must be a negative offset from the maximum supported scheduler priority
    // for the given quality-of-service class. This value must be less than 0 and greater than or
    // equal to QOS_MIN_RELATIVE_PRIORITY, or else the attributes are NULL. If the attributes are
    // NULL, the queue will be created with default unspecified QoS class and relative priority.

    // -- Arrange --
    const char *queueName = "sentry-dispatch-factory.test";
    int relativePriority = 5;
    qos_class_t qosClass = QOS_CLASS_UTILITY;
    dispatch_queue_attr_t _Nullable attr = DISPATCH_QUEUE_SERIAL;

    dispatch_queue_attr_t _Nullable attributes
        = dispatch_queue_attr_make_with_qos_class(attr, qosClass, relativePriority);

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:queueName attributes:attributes];

    // -- Assert --
    XCTAssertNil(attributes);

    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_UNSPECIFIED);
    XCTAssertEqual(actualRelativePriority, 0);
}

- (void)testIsCurrentQueue_whenCalledFromDifferentQueue_shouldReturnFalse
{
    // -- Arrange --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry.test.queue"
                                              attributes:DISPATCH_QUEUE_SERIAL];

    // -- Act & Assert --
    XCTAssertFalse([wrappedQueue isCurrentQueue]);
}

- (void)testIsCurrentQueue_whenCalledFromWithinQueue_shouldReturnTrue
{
    // -- Arrange --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry.test.queue"
                                              attributes:DISPATCH_QUEUE_SERIAL];
    XCTestExpectation *expectation = [self expectationWithDescription:@"queue execution"];

    // -- Act --
    [wrappedQueue dispatchAsyncWithBlock:^{
        // -- Assert --
        XCTAssertTrue([wrappedQueue isCurrentQueue]);
        [expectation fulfill];
    }];

    // -- Wait --
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIsCurrentQueue_whenCalledFromSyncDispatch_shouldReturnTrue
{
    // -- Arrange --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry.test.queue"
                                              attributes:DISPATCH_QUEUE_SERIAL];

    // -- Act & Assert --
    dispatch_sync(wrappedQueue.queue, ^{ XCTAssertTrue([wrappedQueue isCurrentQueue]); });
}

- (void)testIsCurrentQueue_differentInstances_shouldHaveUniqueDetection
{
    // -- Arrange --
    SentryDispatchQueueWrapper *queue1 =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry.test.queue1"
                                              attributes:DISPATCH_QUEUE_SERIAL];
    SentryDispatchQueueWrapper *queue2 =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry.test.queue2"
                                              attributes:DISPATCH_QUEUE_SERIAL];

    // -- Act --
    XCTestExpectation *expectation = [self expectationWithDescription:@"queue execution"];
    [queue1 dispatchAsyncWithBlock:^{
        // -- Assert --
        XCTAssertTrue([queue1 isCurrentQueue], @"queue1 should detect it's on its own queue");
        XCTAssertFalse([queue2 isCurrentQueue], @"queue2 should not detect it's on queue1");
        [expectation fulfill];
    }];
    // -- Wait --
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // -- Act --
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"queue execution 2"];
    [queue2 dispatchAsyncWithBlock:^{
        // -- Assert --
        XCTAssertFalse([queue1 isCurrentQueue], @"queue1 should not detect it's on queue2");
        XCTAssertTrue([queue2 isCurrentQueue], @"queue2 should detect it's on its own queue");
        [expectation2 fulfill];
    }];
    // -- Wait --
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
@end

NS_ASSUME_NONNULL_END
