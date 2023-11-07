#import "SentryBinaryImageCache+Private.h"
#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import <XCTest/XCTest.h>

#include <mach-o/dyld.h>

// Exposing test only functions from `SentryCrashBinaryImageCache.m`
void sentry_setRegisterFuncForAddImage(void *addFunction);
void sentry_setRegisterFuncForRemoveImage(void *removeFunction);
void sentry_resetFuncForAddRemoveImage(void);
void sentry_setFuncForBeforeAdd(void (*callback)(void));

static void (*addBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static void (*removeBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static NSMutableArray *mach_headers_test_cache;
static NSMutableArray *mach_headers_expect_array;

static void
sentry_register_func_for_add_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    addBinaryImage = func;

    if (mach_headers_expect_array) {
        for (NSUInteger i = 0; i < mach_headers_expect_array.count; i++) {
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
    _dyld_register_func_for_add_image(&cacheMachHeaders);
}

- (void)setUp
{
    sentry_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentry_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    // Copying the first 5 images from the temporary list.
    // 5 is a magic number.
    mach_headers_expect_array =
        [mach_headers_test_cache subarrayWithRange:NSMakeRange(0, 5)].mutableCopy;
}

- (void)tearDown
{
    sentry_resetFuncForAddRemoveImage();
    sentrycrashbic_stopCache();
    sentry_setFuncForBeforeAdd(NULL);
    [SentryDependencyContainer reset];
}

- (void)testStartCache
{
    [[SentryCrashWrapper sharedInstance] startBinaryImageCache];
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
    [self assertBinaryImageCacheLength:0];
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
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mach_headers_expect_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];

    NSValue *removeItem = mach_headers_expect_array[0];
    [mach_headers_expect_array removeObjectAtIndex:0];
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
    dispatch_group_t group = dispatch_group_create();

    for (NSUInteger i = 5; i < mach_headers_test_cache.count; i++) {
        dispatch_group_enter(group);
        dispatch_group_async(group, queue, ^{
            addBinaryImage([mach_headers_test_cache[i] pointerValue], 0);
            dispatch_group_leave(group);
        });
    }
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

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
    [imageCache start];
    // by calling start, SentryBinaryImageCache will register a callback with
    // `SentryCrashBinaryImageCache` that should be called for every image already cached.
    XCTAssertEqual(5, imageCache.cache.count);

    addBinaryImage([mach_headers_test_cache[5] pointerValue], 0);
    XCTAssertEqual(6, imageCache.cache.count);

    removeBinaryImage([mach_headers_expect_array[1] pointerValue], 0);
    removeBinaryImage([mach_headers_expect_array[2] pointerValue], 0);
    XCTAssertEqual(4, imageCache.cache.count);
    [imageCache stop];

    addBinaryImage([mach_headers_test_cache[6] pointerValue], 0);
    XCTAssertNil(imageCache.cache);
}

- (void)assertBinaryImageCacheLength:(int)expected
{
    int counter = 0;
    sentrycrashbic_iterateOverImages(countNumberOfImagesInCache, &counter);
    XCTAssertEqual(counter, expected);
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

@end
