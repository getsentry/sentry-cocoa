#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashDynamicLinker+Test.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>

#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <os/lock.h>
#include <unistd.h>

// Exposing test only functions from `SentryCrashBinaryImageCache.c`
void sentry_setRegisterFuncForAddImage(void *addFunction);
void sentry_setRegisterFuncForRemoveImage(void *removeFunction);
void sentry_resetFuncForAddRemoveImage(void);
void sentry_setFuncForBeforeAdd(void (*callback)(void));
void sentrycrashbic_resetForTests(void);
void sentrycrashbic_setMaxImagesForTests(uint32_t maxImages);

static void (*addBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static void (*removeBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static NSMutableArray<NSValue *> *mach_headers_test_cache;
static NSMutableArray<NSValue *> *mach_headers_expect_array;
static os_unfair_lock mach_headers_expect_lock = OS_UNFAIR_LOCK_INIT;
static dispatch_semaphore_t initial_replay_mutation_requested;
static dispatch_semaphore_t initial_replay_mutation_completed;
static bool initial_replay_wait_for_mutation_before_replay = false;
static bool initial_replay_did_wait_for_mutation = false;
static bool initial_replay_mutation_wait_timed_out = false;

static void
reset_initial_replay_mutation_state(void)
{
    os_unfair_lock_lock(&mach_headers_expect_lock);
    initial_replay_mutation_requested = nil;
    initial_replay_mutation_completed = nil;
    initial_replay_wait_for_mutation_before_replay = false;
    initial_replay_did_wait_for_mutation = false;
    initial_replay_mutation_wait_timed_out = false;
    os_unfair_lock_unlock(&mach_headers_expect_lock);
}

static NSArray<NSValue *> *
copy_expected_mach_headers(void)
{
    os_unfair_lock_lock(&mach_headers_expect_lock);
    NSArray<NSValue *> *headers = [mach_headers_expect_array copy];
    os_unfair_lock_unlock(&mach_headers_expect_lock);
    return headers;
}

static void
replace_expected_mach_headers(NSArray<NSValue *> *headers)
{
    os_unfair_lock_lock(&mach_headers_expect_lock);
    mach_headers_expect_array = headers.mutableCopy;
    os_unfair_lock_unlock(&mach_headers_expect_lock);
}

static void
sentry_register_func_for_add_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    addBinaryImage = func;

    NSArray<NSValue *> *headersToReplay = copy_expected_mach_headers();
    if (headersToReplay == nil) {
        return;
    }

    dispatch_semaphore_t mutationRequested = nil;
    dispatch_semaphore_t mutationCompleted = nil;

    os_unfair_lock_lock(&mach_headers_expect_lock);
    if (initial_replay_wait_for_mutation_before_replay && headersToReplay.count > 1
        && initial_replay_mutation_requested != nil && initial_replay_mutation_completed != nil) {
        initial_replay_did_wait_for_mutation = true;
        mutationRequested = initial_replay_mutation_requested;
        mutationCompleted = initial_replay_mutation_completed;
    }
    os_unfair_lock_unlock(&mach_headers_expect_lock);

    if (mutationRequested != nil) {
        dispatch_semaphore_signal(mutationRequested);

        long waitResult = dispatch_semaphore_wait(
            mutationCompleted, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        if (waitResult != 0) {
            os_unfair_lock_lock(&mach_headers_expect_lock);
            initial_replay_mutation_wait_timed_out = true;
            os_unfair_lock_unlock(&mach_headers_expect_lock);
        }
    }

    // Skipping first item which is dyld and already included when starting the cache
    for (NSUInteger i = 1; i < headersToReplay.count; i++) {
        NSValue *header = headersToReplay[i];
        func(header.pointerValue, 0);
    }
}

static void
sentry_register_func_for_remove_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    removeBinaryImage = func;
}

static void
cacheMachHeaders(const struct mach_header *mh, __unused intptr_t vmaddr_slide)
{
    [mach_headers_test_cache addObject:[NSValue valueWithPointer:mh]];
}

static void
countNumberOfImagesInCache(__unused SentryCrashBinaryImage *image, void *context)
{
    int *counter = context;
    (*counter)++;
}

static void
addBinaryImageToArray(SentryCrashBinaryImage *image, void *context)
{
    NSMutableArray *array = (__bridge NSMutableArray *)context;
    [array addObject:[NSValue valueWithPointer:image]];
}

static void
addBinaryImageAddressToArray(SentryCrashBinaryImage *image, void *context)
{
    NSMutableArray<NSNumber *> *array = (__bridge NSMutableArray<NSNumber *> *)context;
    [array addObject:@(image->address)];
}

static void
addBinaryImageNameToArray(SentryCrashBinaryImage *image, void *context)
{
    NSMutableArray *array = (__bridge NSMutableArray *)context;
    if (image->name) {
        [array addObject:[NSString stringWithUTF8String:image->name]];
    } else {
        [array addObject:@"<null>"];
    }
}

dispatch_semaphore_t delaySemaphore = NULL;
dispatch_semaphore_t delayCalled = NULL;
static void
delayAddBinaryImage(void)
{
    if (delayCalled) {
        dispatch_semaphore_signal(delayCalled);
    }
    if (delaySemaphore) {
        dispatch_semaphore_wait(delaySemaphore, DISPATCH_TIME_FOREVER);
    }
}

@interface SentryCrashBinaryImageCacheTests : XCTestCase

@end

@implementation SentryCrashBinaryImageCacheTests

+ (void)setUp
{
    // Create a test cache of actual binary images to be used during tests.
    mach_headers_test_cache = [NSMutableArray array];

    // Manually include dyld
    sentrycrashdl_initialize();
    [mach_headers_test_cache addObject:[NSValue valueWithPointer:sentryDyldHeader]];
    _dyld_register_func_for_add_image(&cacheMachHeaders);
}

- (void)setUp
{
    sentry_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentry_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);
    reset_initial_replay_mutation_state();

    // Copying the first 5 images from the temporary list.
    // 5 is a magic number.
    replace_expected_mach_headers([mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 5)]);
}

- (void)tearDown
{
    sentrycrashdl_clearDyld();
    sentrycrashbic_resetForTests();
    sentry_resetFuncForAddRemoveImage();
    sentry_setFuncForBeforeAdd(NULL);
    reset_initial_replay_mutation_state();
    [SentryDependencyContainer reset];
}

- (void)testStartCache
{
    // -- Arrange --

    // -- Act --
    [SentryDependencyContainer.sharedInstance.crashWrapper startBinaryImageCache];

    // -- Assert --
    [self assertBinaryImageCacheLength:5];

    SentryCrashBinaryImageCacheDebugInfo debugInfo = [self debugInfo];
    XCTAssertEqual(debugInfo.populatedImageCount, 5);
    XCTAssertFalse(debugInfo.overflowed);
    XCTAssertGreaterThan(debugInfo.bootstrapDurationNanos, 0ULL);
}

- (void)testGetDebugInfo_whenCacheNotStarted_shouldReportEmptyState
{
    // -- Arrange --
    SentryCrashBinaryImageCacheDebugInfo debugInfo = { 0 };

    // -- Act --
    sentrycrashbic_getDebugInfo(&debugInfo);

    // -- Assert --
    XCTAssertEqual(debugInfo.populatedImageCount, 0);
    XCTAssertFalse(debugInfo.overflowed);
    XCTAssertEqual(debugInfo.bootstrapDurationNanos, 0ULL);
}

- (void)testStartCacheTwice
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];
}

- (void)testStopCache
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];
    sentrycrashbic_stopCache();
    [self assertBinaryImageCacheLength:0];
}

- (void)testStopCacheTwice
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];
    sentrycrashbic_stopCache();
    [self assertBinaryImageCacheLength:0];
    sentrycrashbic_stopCache();
    [self assertBinaryImageCacheLength:0];
}

- (void)testAddNewImage
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    replace_expected_mach_headers([mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 6)]);
    [self assertBinaryImageCacheLength:6];
    [self assertCachedBinaryImages];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    replace_expected_mach_headers([mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 7)]);
    [self assertBinaryImageCacheLength:7];
    [self assertCachedBinaryImages];
}

- (void)testAddInvalidHeader
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    addBinaryImage(0, 0);
    [self assertBinaryImageCacheLength:5];
}

- (void)testStartCache_whenBootstrapExceedsCapacity_shouldSetOverflowFlag
{
    // -- Arrange --
    NSArray<NSValue *> *expectedHeadersAfterOverflow =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 2)];
    sentrycrashbic_setMaxImagesForTests(2);

    // -- Act --
    sentrycrashbic_startCache();

    // -- Assert --
    replace_expected_mach_headers(expectedHeadersAfterOverflow);
    [self assertBinaryImageCacheLength:2];
    [self assertCachedBinaryImages];

    SentryCrashBinaryImageCacheDebugInfo debugInfo = [self debugInfo];
    XCTAssertEqual(debugInfo.populatedImageCount, 2);
    XCTAssertTrue(debugInfo.overflowed);
    XCTAssertGreaterThan(debugInfo.bootstrapDurationNanos, 0ULL);
}

- (void)testAddNewImage_whenCacheExceedsCapacity_shouldSetOverflowFlag
{
    // -- Arrange --
    sentrycrashbic_setMaxImagesForTests(5);
    sentrycrashbic_startCache();

    // -- Act --
    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);

    // -- Assert --
    [self assertBinaryImageCacheLength:5];
    [self assertCachedBinaryImages];

    SentryCrashBinaryImageCacheDebugInfo debugInfo = [self debugInfo];
    XCTAssertEqual(debugInfo.populatedImageCount, 5);
    XCTAssertTrue(debugInfo.overflowed);
    XCTAssertGreaterThan(debugInfo.bootstrapDurationNanos, 0ULL);
}

- (void)testIterateOverImages_whenProducerAppendsConcurrently_shouldRemainConsistent
{
    // -- Arrange --
    sentrycrashbic_startCache();

    XCTAssertGreaterThan(mach_headers_test_cache.count, 13UL);

    NSArray<NSValue *> *additionalHeaders =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(5, 8)];
    NSMutableSet<NSNumber *> *expectedAddresses = [NSMutableSet set];
    for (NSValue *value in copy_expected_mach_headers()) {
        [expectedAddresses addObject:@((uint64_t)value.pointerValue)];
    }
    for (NSValue *value in additionalHeaders) {
        [expectedAddresses addObject:@((uint64_t)value.pointerValue)];
    }

    const int readerCount = 4;
    const int readerIterations = 2000;
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue
        = dispatch_queue_create("io.sentry.binary-image-cache.stress", DISPATCH_QUEUE_CONCURRENT);

    // -- Act --
    for (int readerIndex = 0; readerIndex < readerCount; readerIndex++) {
        dispatch_group_async(group, queue, ^{
            for (int iteration = 0; iteration < readerIterations; iteration++) {
                NSMutableArray<NSNumber *> *snapshot = [NSMutableArray array];
                sentrycrashbic_iterateOverImages(
                    addBinaryImageAddressToArray, (__bridge void *)(snapshot));

                NSSet<NSNumber *> *snapshotSet = [NSSet setWithArray:snapshot];
                if (snapshot.count != snapshotSet.count) {
                    @synchronized(errors) {
                        [errors addObject:@"Reader observed duplicate binary-image addresses."];
                    }
                    return;
                }

                if (![snapshotSet isSubsetOfSet:expectedAddresses]) {
                    @synchronized(errors) {
                        [errors addObject:@"Reader observed an unknown binary-image address."];
                    }
                    return;
                }
            }
        });
    }

    dispatch_group_async(group, queue, ^{
        for (NSValue *value in additionalHeaders) {
            addBinaryImage(value.pointerValue, 0);
            usleep(100);
        }
    });

    long waitResult
        = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

    // -- Assert --
    XCTAssertEqual(waitResult, 0L);
    XCTAssertEqual(errors.count, 0UL, @"%@", [errors componentsJoinedByString:@"\n"]);

    NSArray<NSValue *> *expectedHeadersAfterAppend =
        [copy_expected_mach_headers() arrayByAddingObjectsFromArray:additionalHeaders];
    replace_expected_mach_headers(expectedHeadersAfterAppend);
    [self assertBinaryImageCacheLength:(int)expectedHeadersAfterAppend.count];
    [self assertCachedBinaryImages];
}

- (void)testStartCache_whenReplayAppendsDuringBootstrap_shouldRemainConsistent
{
    // -- Arrange --
    XCTAssertGreaterThan(mach_headers_test_cache.count, 9UL);

    NSArray<NSValue *> *headersVisibleAtStart = copy_expected_mach_headers();
    NSArray<NSValue *> *headersAppendedDuringStart =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(5, 4)];

    os_unfair_lock_lock(&mach_headers_expect_lock);
    initial_replay_mutation_requested = dispatch_semaphore_create(0);
    initial_replay_mutation_completed = dispatch_semaphore_create(0);
    initial_replay_wait_for_mutation_before_replay = true;
    os_unfair_lock_unlock(&mach_headers_expect_lock);

    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create(
        "io.sentry.binary-image-cache.start-replay", DISPATCH_QUEUE_CONCURRENT);

    // -- Act --
    dispatch_group_async(group, queue, ^{
        long requestWait = dispatch_semaphore_wait(
            initial_replay_mutation_requested, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        if (requestWait != 0) {
            @synchronized(errors) {
                [errors addObject:@"Mutator did not observe the initial replay start."];
            }
            dispatch_semaphore_signal(initial_replay_mutation_completed);
            return;
        }

        for (NSValue *value in headersAppendedDuringStart) {
            addBinaryImage(value.pointerValue, 0);
        }

        dispatch_semaphore_signal(initial_replay_mutation_completed);
    });

    dispatch_group_async(group, queue, ^{ sentrycrashbic_startCache(); });

    long waitResult
        = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

    // -- Assert --
    XCTAssertEqual(waitResult, 0L);
    XCTAssertEqual(errors.count, 0UL, @"%@", [errors componentsJoinedByString:@"\n"]);

    bool didWaitForMutation = false;
    bool mutationWaitTimedOut = false;
    os_unfair_lock_lock(&mach_headers_expect_lock);
    didWaitForMutation = initial_replay_did_wait_for_mutation;
    mutationWaitTimedOut = initial_replay_mutation_wait_timed_out;
    os_unfair_lock_unlock(&mach_headers_expect_lock);

    XCTAssertTrue(didWaitForMutation);
    XCTAssertFalse(mutationWaitTimedOut);

    NSMutableSet<NSNumber *> *startAddresses = [NSMutableSet set];
    for (NSValue *value in headersVisibleAtStart) {
        [startAddresses addObject:@((uint64_t)value.pointerValue)];
    }

    NSMutableArray<NSNumber *> *cachedAddresses = [NSMutableArray array];
    sentrycrashbic_iterateOverImages(
        addBinaryImageAddressToArray, (__bridge void *)(cachedAddresses));

    NSSet<NSNumber *> *cachedAddressSet = [NSSet setWithArray:cachedAddresses];
    XCTAssertEqual(cachedAddresses.count, cachedAddressSet.count);
    XCTAssertTrue([startAddresses isSubsetOfSet:cachedAddressSet]);

    NSMutableArray<NSValue *> *finalExpectedHeaders = [NSMutableArray array];
    [finalExpectedHeaders addObject:headersVisibleAtStart[0]];
    [finalExpectedHeaders addObjectsFromArray:headersAppendedDuringStart];
    [finalExpectedHeaders
        addObjectsFromArray:[headersVisibleAtStart
                                subarrayWithRange:NSMakeRange(1, headersVisibleAtStart.count - 1)]];
    replace_expected_mach_headers(finalExpectedHeaders);

    [self assertBinaryImageCacheLength:(int)finalExpectedHeaders.count];
    [self assertCachedBinaryImages];
}

- (void)testAddNewImageAfterStopping
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    sentrycrashbic_stopCache();
    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    [self assertBinaryImageCacheLength:0];
}

- (void)testRemoveImageFromTail
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    NSMutableArray<NSValue *> *expectedMachHeaders = copy_expected_mach_headers().mutableCopy;

    removeBinaryImage([expectedMachHeaders[4] pointerValue], 0);
    [expectedMachHeaders removeObjectAtIndex:4];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertBinaryImageCacheLength:4];
    [self assertCachedBinaryImages];

    removeBinaryImage([expectedMachHeaders[3] pointerValue], 0);
    [expectedMachHeaders removeObjectAtIndex:3];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertBinaryImageCacheLength:3];
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageFromBeginning
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    NSMutableArray<NSValue *> *expectedMachHeaders = copy_expected_mach_headers().mutableCopy;

    removeBinaryImage([expectedMachHeaders[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];
    [expectedMachHeaders removeObjectAtIndex:0];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertCachedBinaryImages];

    removeBinaryImage([expectedMachHeaders[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:3];
    [expectedMachHeaders removeObjectAtIndex:0];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageAddAgain
{
    // Use index 1 since we can't dynamically insert dyld image (`dladdr` returns null)
    int indexToRemove = 1;

    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    NSMutableArray<NSValue *> *expectedMachHeaders = copy_expected_mach_headers().mutableCopy;

    removeBinaryImage([expectedMachHeaders[indexToRemove] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];

    NSValue *removeItem = expectedMachHeaders[indexToRemove];
    [expectedMachHeaders removeObjectAtIndex:indexToRemove];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertCachedBinaryImages];

    addBinaryImage(removeItem.pointerValue, 0);
    [self assertBinaryImageCacheLength:5];
    [expectedMachHeaders insertObject:removeItem atIndex:4];
    replace_expected_mach_headers(expectedMachHeaders);
    [self assertCachedBinaryImages];
}

- (void)testAddBinaryImageInParallel
{
    sentrycrashbic_startCache();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    // Guard against underflow when mach_headers_test_cache.count < 5
    // because otherwise the expectedFulfillmentCount for the test expectation will be negative.
    NSInteger taskCount = mach_headers_test_cache.count - 5;
    if (taskCount <= 0) {
        XCTFail(@"Expected a positive task count, but got %ld", taskCount);
        return;
    }

    XCTestExpectation *expectation =
        [self expectationWithDescription:@"Add binary images in parallel"];
    expectation.expectedFulfillmentCount = taskCount;

    for (NSUInteger i = 5; i < mach_headers_test_cache.count; i++) {
        dispatch_async(queue, ^{
            addBinaryImage([mach_headers_test_cache[i] pointerValue], 0);
            [expectation fulfill];
        });
    }

    [self waitForExpectations:@[ expectation ] timeout:5.0];

    [self assertBinaryImageCacheLength:(int)mach_headers_test_cache.count];
}

- (void)testCloseCacheWhileAdding
{
    sentrycrashbic_startCache();
    sentry_setFuncForBeforeAdd(&delayAddBinaryImage);
    delaySemaphore = dispatch_semaphore_create(0);
    delayCalled = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{ addBinaryImage([mach_headers_test_cache[6] pointerValue], 0); });

    intptr_t result
        = dispatch_semaphore_wait(delayCalled, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    sentrycrashbic_stopCache();
    dispatch_semaphore_signal(delaySemaphore);
    [self assertBinaryImageCacheLength:0];
    XCTAssertEqual(result, 0);
}

// Adding a SentryBinaryImageCache test inside
// SentryCrashBinaryImageCache to test integration between both
// because is easier to control SentryCrashBinaryImageCache in an objc test
- (void)testSentryBinaryImageCacheIntegration
{
    sentrycrashbic_startCache();

    SentryBinaryImageCache *imageCache = SentryDependencyContainer.sharedInstance.binaryImageCache;
    [imageCache start:false];
    // by calling start, SentryBinaryImageCache will register a callback with
    // `SentryCrashBinaryImageCache` that should be called for every image already cached.
    NSMutableArray<NSString *> *paths = [NSMutableArray new];
    [imageCache.cache enumerateObjectsUsingBlock:^(SentryBinaryImageInfo *_Nonnull obj,
        NSUInteger __unused idx, BOOL *_Nonnull __unused stop) { [paths addObject:obj.name]; }];
    XCTAssertEqual(
        5, imageCache.cache.count, @"Cache should start with 5 images but contained %@", paths);

    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    XCTAssertEqual(6, imageCache.cache.count);

    NSArray<NSValue *> *expectedMachHeaders = copy_expected_mach_headers();
    removeBinaryImage([expectedMachHeaders[1] pointerValue], 0);
    removeBinaryImage([expectedMachHeaders[2] pointerValue], 0);
    XCTAssertEqual(4, imageCache.cache.count);
    [imageCache stop];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    XCTAssertNil(imageCache.cache);
}

- (SentryCrashBinaryImageCacheDebugInfo)debugInfo
{
    SentryCrashBinaryImageCacheDebugInfo debugInfo = { 0 };
    sentrycrashbic_getDebugInfo(&debugInfo);
    return debugInfo;
}

- (void)assertBinaryImageCacheLength:(int)expected
{
    int counter = 0;
    sentrycrashbic_iterateOverImages(countNumberOfImagesInCache, &counter);
    NSMutableArray<NSString *> *names = [NSMutableArray new];
    sentrycrashbic_iterateOverImages(addBinaryImageNameToArray, (__bridge void *)(names));
    XCTAssertEqual(
        counter, expected, @"Cache should have %d images but contained %@", expected, names);
}

- (void)assertCachedBinaryImages
{
    NSArray<NSValue *> *cached = [self binaryImageCacheToArray];
    NSArray<NSValue *> *expectedMachHeaders = copy_expected_mach_headers();

    XCTAssertEqual(cached.count, expectedMachHeaders.count);
    for (NSUInteger i = 0; i < cached.count; i++) {
        SentryCrashBinaryImage *binaryImage = [cached[i] pointerValue];
        struct mach_header *header = [expectedMachHeaders[i] pointerValue];
        XCTAssertEqual(binaryImage->address, (uint64_t)header);
    }
}

- (NSArray *)binaryImageCacheToArray
{
    NSMutableArray *result = [NSMutableArray array];
    sentrycrashbic_iterateOverImages(addBinaryImageToArray, (__bridge void *)(result));
    return result;
}

@end
