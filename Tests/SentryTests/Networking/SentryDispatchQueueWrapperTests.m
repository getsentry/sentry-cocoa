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
@end

NS_ASSUME_NONNULL_END
