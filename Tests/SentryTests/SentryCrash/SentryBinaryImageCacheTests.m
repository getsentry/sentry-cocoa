#import "SentryCrashBinaryImageCache.h"
#import <XCTest/XCTest.h>
#include <mach-o/dyld.h>

// Exposing test only functions from `SentryCrashBinaryImageCache.m`
void sentry_setRegisterFuncForAddImage(void *addFunction);
void sentry_setRegisterFuncForRemoveImage(void *removeFunction);
void sentry_resetFuncForAddRemoveImage(void);

static void (*addBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static void (*removeBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static NSMutableArray *mech_headers_test_cache;
static NSMutableArray *mech_headers_initial_array;

static void
sentry_register_func_for_add_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    addBinaryImage = func;

    if (mech_headers_initial_array) {
        for (NSUInteger i = 0; i < mech_headers_initial_array.count; i++) {
            NSValue *header = mech_headers_initial_array[i];
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
    [mech_headers_test_cache addObject:[NSValue valueWithPointer:mh]];
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

@interface SentryBinaryImageCacheTests : XCTestCase

@end

@implementation SentryBinaryImageCacheTests

+ (void)setUp
{
    // Create a test cache of actual binary images to be used during tests.
    mech_headers_test_cache = [NSMutableArray array];
    _dyld_register_func_for_add_image(&cacheMachHeaders);
}

- (void)setUp
{
    sentry_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentry_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);

    mech_headers_initial_array =
        [mech_headers_test_cache subarrayWithRange:NSMakeRange(0, 5)].mutableCopy;
}

- (void)tearDown
{
    sentry_resetFuncForAddRemoveImage();
    sentrycrashbic_stopCache();
}

- (void)testStartCache
{
    sentrycrashbic_startCache();
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

    addBinaryImage([mech_headers_test_cache[5] pointerValue], 0);
    mech_headers_initial_array =
        [mech_headers_test_cache subarrayWithRange:NSMakeRange(0, 6)].mutableCopy;
    [self assertBinaryImageCacheLength:6];
    [self assertCachedBinaryImages];

    addBinaryImage([mech_headers_test_cache[6] pointerValue], 0);
    mech_headers_initial_array =
        [mech_headers_test_cache subarrayWithRange:NSMakeRange(0, 7)].mutableCopy;
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

- (void)testAddNewImageAfterStopping {
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    sentrycrashbic_stopCache();
    addBinaryImage([mech_headers_test_cache[6] pointerValue], 0);
    [self assertBinaryImageCacheLength:0];
}

- (void)testRemoveImageFromTail
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mech_headers_initial_array[4] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];
    [self assertCachedBinaryImages];

    removeBinaryImage([mech_headers_initial_array[3] pointerValue], 0);
    [self assertBinaryImageCacheLength:3];
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageFromBeginning
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mech_headers_initial_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];
    [mech_headers_initial_array removeObjectAtIndex:0];
    [self assertCachedBinaryImages];

    removeBinaryImage([mech_headers_initial_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:3];
    [mech_headers_initial_array removeObjectAtIndex:0];
    [self assertCachedBinaryImages];
}

- (void)testRemoveImageAddAgain
{
    sentrycrashbic_startCache();
    [self assertBinaryImageCacheLength:5];

    removeBinaryImage([mech_headers_initial_array[0] pointerValue], 0);
    [self assertBinaryImageCacheLength:4];

    NSValue *removeItem = mech_headers_initial_array[0];
    [mech_headers_initial_array removeObjectAtIndex:0];
    [self assertCachedBinaryImages];

    addBinaryImage(removeItem.pointerValue, 0);
    [self assertBinaryImageCacheLength:5];
    [mech_headers_initial_array insertObject:removeItem atIndex:4];
    [self assertCachedBinaryImages];
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
        struct mach_header *header = [mech_headers_initial_array[i] pointerValue];
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
