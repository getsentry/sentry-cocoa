#import <KSMachineContext.h>
#import <XCTest/XCTest.h>

@interface ReservedThreadContractTests : XCTestCase
@end

@implementation ReservedThreadContractTests

- (void)testQuery_whenSingleWriterPublishesToConcurrentReaders_shouldBeRaceFree
{
    // -- Arrange --
    // Use two process-lifetime registry slots. Registration, unlike lookup, is serialized.
    const KSThread firstThread = 0x7fff0000;
    const KSThread secondThread = 0x7fff0001;
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue
        = dispatch_queue_create("reserved-registry-race", DISPATCH_QUEUE_CONCURRENT);
    dispatch_semaphore_t start = dispatch_semaphore_create(0);
    XCTAssertFalse(ksmc_isReservedThread(firstThread));
    XCTAssertFalse(ksmc_isReservedThread(secondThread));

    // -- Act --
    dispatch_group_async(group, queue, ^{
        dispatch_semaphore_wait(start, DISPATCH_TIME_FOREVER);
        ksmc_addReservedThread(firstThread);
        ksmc_addReservedThread(secondThread);
    });
    for (int reader = 0; reader < 4; reader++) {
        dispatch_group_async(group, queue, ^{
            dispatch_semaphore_wait(start, DISPATCH_TIME_FOREVER);
            for (int i = 0; i < 10000; i++) {
                (void)ksmc_isReservedThread(firstThread);
                (void)ksmc_isReservedThread(secondThread);
            }
        });
    }
    for (int i = 0; i < 5; i++) {
        dispatch_semaphore_signal(start);
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    // -- Assert --
    XCTAssertTrue(ksmc_isReservedThread(firstThread));
    XCTAssertTrue(ksmc_isReservedThread(secondThread));
    XCTAssertFalse(ksmc_isReservedThread(secondThread + 1));
}

@end
