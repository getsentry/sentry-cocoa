#import "SentrySwift.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDispatchQueueWrapperTests : XCTestCase

@end

@implementation SentryDispatchQueueWrapperTests

- (void)testInitWithNameAndAttributes_shouldCreateQueueWithName
{
    // -- Arrange --
    NSString *queueName = @"sentry-dispatch-factory.test";

    // -- Act --
    SentryDispatchQueueWrapper *wrappedQueue =
        [[SentryDispatchQueueWrapper alloc] initWithUtilityNamed:queueName];

    // -- Assert --
    const char *actualName = dispatch_queue_get_label(wrappedQueue.queue);
    XCTAssertEqual(strcmp(actualName, [queueName cStringUsingEncoding:NSUTF8StringEncoding]), 0);

    int actualRelativePriority;
    dispatch_qos_class_t actualQoSClass
        = dispatch_queue_get_qos_class(wrappedQueue.queue, &actualRelativePriority);
    XCTAssertEqual(actualQoSClass, QOS_CLASS_UTILITY);
}
@end

NS_ASSUME_NONNULL_END
