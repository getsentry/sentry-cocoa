#import "SentryCrashBinaryImageCache+Test.h"
#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashDynamicLinker+Test.h"
#import "SentrySwift.h"
#import <XCTest/XCTest.h>

#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>

// Test-only functions are declared in `SentryCrashBinaryImageCache+Test.h`

static void (*addBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static void (*removeBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static NSMutableArray *mach_headers_test_cache;
static NSMutableArray *mach_headers_expect_array;
static const uint32_t maxDyldImages = 4096;

static void
sentry_register_func_for_add_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    addBinaryImage = func;

    if (mach_headers_expect_array) {
        // Skipping first item which is dyld and already included when starting the cache
        for (NSUInteger i = 1; i < mach_headers_expect_array.count; i++) {
            NSValue *header = mach_headers_expect_array[i];
            func(header.pointerValue, 0);
        }
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
addBinaryImageNameToArray(SentryCrashBinaryImage *image, void *context)
{
    NSMutableArray *array = (__bridge NSMutableArray *)context;
    if (image->name) {
        [array addObject:[NSString stringWithUTF8String:image->name]];
    } else {
        [array addObject:@"<null>"];
    }
}

static NSMutableArray<NSString *> *added_image_names;

static void
captureAddedImageName(const SentryCrashBinaryImage *image)
{
    @synchronized(added_image_names) {
        if (image->name) {
            [added_image_names addObject:[NSString stringWithUTF8String:image->name]];
        } else {
            [added_image_names addObject:@"<null>"];
        }
    }
}

static NSArray<NSString *> *
copyAddedImageNames(void)
{
    @synchronized(added_image_names) {
        return [added_image_names copy] ?: @[];
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
    sentrycrashbic_useFreshTestCacheState();
    sentrycrashbic_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    added_image_names = [NSMutableArray array];
    delaySemaphore = NULL;
    delayCalled = NULL;

    // Copying the first 5 images from the temporary list.
    // 5 is a magic number.
    mach_headers_expect_array =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 5)].mutableCopy;
}

- (void)tearDown
{
    added_image_names = nil;
    delaySemaphore = NULL;
    delayCalled = NULL;

    sentrycrashdl_clearDyld();
    sentrycrashbic_useDefaultCacheState();
    [SentryDependencyContainer reset];
}

- (void)testStartCache
{
    [SentryDependencyContainer.sharedInstance.crashWrapper startBinaryImageCache];
    [self assertBinaryImageCacheLength:5];
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
    [self assertBinaryImageCacheLength:5];
}

- (void)testStopCacheTwice
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];
    sentrycrashbic_stopCache();
    [self assertBinaryImageCacheLength:5];
    sentrycrashbic_stopCache();
    [self assertBinaryImageCacheLength:5];
}

- (void)testRegisterAddedCallbackBeforeStartingCache
{
    // Deterministically simulates the async production path where the callback is installed before
    // `addDyldImage()` runs.
    sentrycrashbic_registerAddedCallback(&captureAddedImageName);

    sentrycrashbic_startCache();

    NSArray<NSString *> *names = copyAddedImageNames();
    XCTAssertEqual(5, names.count);
    XCTAssertTrue([names containsObject:@"dyld"]);
}

- (void)testUseFreshTestCacheState_whenSwitchingStates_shouldResetAndIsolateTheActiveCache
{
    sentrycrashbic_useDefaultCacheState();
    sentrycrashbic_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    sentrycrashbic_startCache();
    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    [self assertBinaryImageCacheLength:6];

    sentrycrashbic_useFreshTestCacheState();
    sentrycrashbic_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    [self assertBinaryImageCacheLength:6];

    sentrycrashbic_useDefaultCacheState();
    sentrycrashbic_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];
}

- (void)testAddNewImage
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    mach_headers_expect_array =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 6)].mutableCopy;
    [self assertBinaryImageCacheLength:6];
    [self assertCachedBinaryImages];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    mach_headers_expect_array =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 7)].mutableCopy;
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

- (void)testAddNewImageAfterStopping
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    sentrycrashbic_stopCache();
    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    [self assertBinaryImageCacheLength:6];
}

- (void)testRemoveImageFromTail
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mach_headers_expect_array[4] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];
    [self assertCachedBinaryImages];

    removeBinaryImage([mach_headers_expect_array[3] pointerValue], 0);
    [self assertBinaryImageCacheLength:3];
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageFromBeginning
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mach_headers_expect_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];
    [mach_headers_expect_array removeObjectAtIndex:0];
    [self assertCachedBinaryImages];

    removeBinaryImage([mach_headers_expect_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:3];
    [mach_headers_expect_array removeObjectAtIndex:0];
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageAddAgain
{
    // Use index 1 since we can't dynamically insert dyld image (`dladdr` returns null)
    int indexToRemove = 1;

    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mach_headers_expect_array[indexToRemove] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];

    NSValue *removeItem = mach_headers_expect_array[indexToRemove];
    [mach_headers_expect_array removeObjectAtIndex:indexToRemove];
    [self assertCachedBinaryImages];

    addBinaryImage(removeItem.pointerValue, 0);
    [self assertBinaryImageCacheLength:5];
    [mach_headers_expect_array insertObject:removeItem atIndex:4];
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
    sentrycrashbic_setBeforeAddImageCallback(&delayAddBinaryImage);
    delaySemaphore = dispatch_semaphore_create(0);
    delayCalled = dispatch_semaphore_create(0);
    dispatch_semaphore_t addFinished = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
        dispatch_semaphore_signal(addFinished);
    });

    intptr_t result
        = dispatch_semaphore_wait(delayCalled, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    sentrycrashbic_stopCache();
    dispatch_semaphore_signal(delaySemaphore);
    intptr_t addResult
        = dispatch_semaphore_wait(addFinished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    [self assertBinaryImageCacheLength:6];
    XCTAssertEqual(result, 0);
    XCTAssertEqual(addResult, 0);
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

    removeBinaryImage([mach_headers_expect_array[1] pointerValue], 0);
    removeBinaryImage([mach_headers_expect_array[2] pointerValue], 0);
    XCTAssertEqual(4, imageCache.cache.count);
    [imageCache stop];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    XCTAssertNil(imageCache.cache);
}

- (void)testImagesAddedWhileSwiftCacheStopped_AreReplayedOnRestart
{
    sentrycrashbic_startCache();

    SentryBinaryImageCache *imageCache = SentryDependencyContainer.sharedInstance.binaryImageCache;
    [imageCache start:false];
    XCTAssertEqual(5, imageCache.cache.count);

    [imageCache stop];
    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    XCTAssertNil(imageCache.cache);

    [imageCache start:false];
    XCTAssertEqual(6, imageCache.cache.count);
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
    NSArray *cached = [self binaryImageCacheToArray];
    for (NSUInteger i = 0; i < cached.count; i++) {
        SentryCrashBinaryImage *binaryImage = [cached[i] pointerValue];
        struct mach_header *header = [mach_headers_expect_array[i] pointerValue];
        XCTAssertEqual(binaryImage->address, (uint64_t)header);
    }
}

- (NSArray *)binaryImageCacheToArray
{
    NSMutableArray *result = [NSMutableArray array];
    sentrycrashbic_iterateOverImages(addBinaryImageToArray, (__bridge void *)(result));
    return result;
}

- (const struct mach_header *)capacityTestHeader
{
    return [mach_headers_expect_array[1] pointerValue];
}

- (void)bootstrapDyldCallbacksAndResetCacheState
{
    sentrycrashbic_startCache();
    sentrycrashbic_useFreshTestCacheState();
    sentrycrashbic_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);
}

- (void)fillStartedCacheToImageLimitWithHeader:(const struct mach_header *)header
{
    for (uint32_t i = 5; i < maxDyldImages; i++) {
        addBinaryImage(header, 0);
    }
}

- (void)fillInactiveCacheToImageLimitWithHeader:(const struct mach_header *)header
{
    for (uint32_t i = 0; i < maxDyldImages; i++) {
        addBinaryImage(header, 0);
    }
}

- (void)testAddImage_whenCacheIsAtCapacity_shouldIgnoreOverflowImage
{
    const struct mach_header *header = [self capacityTestHeader];

    sentrycrashbic_startCache();
    [self fillStartedCacheToImageLimitWithHeader:header];
    [self assertBinaryImageCacheLength:maxDyldImages];

    sentrycrashbic_registerAddedCallback(&captureAddedImageName);
    XCTAssertEqual((NSUInteger)maxDyldImages, copyAddedImageNames().count);

    addBinaryImage(header, 0);

    XCTAssertEqual((NSUInteger)maxDyldImages, copyAddedImageNames().count);
    [self assertBinaryImageCacheLength:maxDyldImages];
}

- (void)testStartCache_whenCacheIsAtCapacity_shouldSkipAddingDyld
{
    const struct mach_header *header = [self capacityTestHeader];

    [self bootstrapDyldCallbacksAndResetCacheState];
    [self fillInactiveCacheToImageLimitWithHeader:header];

    NSMutableArray<NSString *> *namesBeforeStart = [NSMutableArray array];
    sentrycrashbic_iterateOverImages(
        addBinaryImageNameToArray, (__bridge void *)(namesBeforeStart));
    XCTAssertEqual((NSUInteger)maxDyldImages, namesBeforeStart.count);
    XCTAssertFalse([namesBeforeStart containsObject:@"dyld"]);

    sentrycrashbic_startCache();

    NSMutableArray<NSString *> *namesAfterStart = [NSMutableArray array];
    sentrycrashbic_iterateOverImages(addBinaryImageNameToArray, (__bridge void *)(namesAfterStart));
    XCTAssertEqual((NSUInteger)maxDyldImages, namesAfterStart.count);
    XCTAssertFalse([namesAfterStart containsObject:@"dyld"]);
}

- (void)testIterateOverImages_whenNextIndexExceedsMax_shouldIgnoreOverflowSlot
{
    const struct mach_header *header = [self capacityTestHeader];

    [self bootstrapDyldCallbacksAndResetCacheState];
    [self fillInactiveCacheToImageLimitWithHeader:header];
    addBinaryImage(header, 0);

    XCTAssertEqual((NSUInteger)maxDyldImages, [self binaryImageCacheToArray].count);
}

- (void)testRegisterAddedCallback_whenNextIndexExceedsMax_shouldReplayOnlyTrackedImages
{
    const struct mach_header *header = [self capacityTestHeader];

    [self bootstrapDyldCallbacksAndResetCacheState];
    [self fillInactiveCacheToImageLimitWithHeader:header];
    addBinaryImage(header, 0);

    sentrycrashbic_registerAddedCallback(&captureAddedImageName);

    NSArray<NSString *> *replayedNames = copyAddedImageNames();
    XCTAssertEqual((NSUInteger)maxDyldImages, replayedNames.count);
    XCTAssertFalse([replayedNames containsObject:@"dyld"]);
}

- (void)testRemoveImage_whenNextIndexExceedsMax_shouldRemoveTrackedImage
{
    const struct mach_header *header = [self capacityTestHeader];

    [self bootstrapDyldCallbacksAndResetCacheState];
    [self fillInactiveCacheToImageLimitWithHeader:header];
    addBinaryImage(header, 0);

    removeBinaryImage(header, 0);

    [self assertBinaryImageCacheLength:maxDyldImages - 1];
}

@end
