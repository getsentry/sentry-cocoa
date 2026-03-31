#import "SentryCrashBinaryImageCache.h"
#import "SentryCrashDynamicLinker+Test.h"
#import <XCTest/XCTest.h>

#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdatomic.h>

void sentry_setRegisterFuncForAddImage(void *addFunction);
void sentry_setRegisterFuncForRemoveImage(void *removeFunction);
void sentry_resetFuncForAddRemoveImage(void);
void sentry_setFuncForBeforeAdd(void (*callback)(void));

static void (*s_addBinaryImage)(const struct mach_header *mh, intptr_t vmaddr_slide);
static NSMutableArray *s_machHeaders;
static dispatch_semaphore_t s_iterationStarted;
static atomic_int s_iterationCount;

static void
sentry_register_func_for_add_image(
    void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
    s_addBinaryImage = func;
    for (NSUInteger i = 1; i < s_machHeaders.count; i++) {
        func([s_machHeaders[i] pointerValue], 0);
    }
}

static void
sentry_register_func_for_remove_image(
    __unused void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide))
{
}

/// Simulates cold-start page fault latency (150µs per image).
static void
slowIterationCallback(const SentryCrashBinaryImage *__unused image)
{
    if (atomic_fetch_add(&s_iterationCount, 1) == 0) {
        dispatch_semaphore_signal(s_iterationStarted);
    }
    usleep(150);
}

static void
countImages(SentryCrashBinaryImage *__unused image, void *context)
{
    (*(int *)context)++;
}

@interface SentryCrashBinaryImageCacheMainThreadBlockingTests : XCTestCase
@end

@implementation SentryCrashBinaryImageCacheMainThreadBlockingTests

+ (void)setUp
{
    s_machHeaders = [NSMutableArray array];
    sentrycrashdl_initialize();
    [s_machHeaders addObject:[NSValue valueWithPointer:sentryDyldHeader]];

    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (header != NULL) {
            [s_machHeaders addObject:[NSValue valueWithPointer:header]];
        }
    }
}

- (void)setUp
{
    sentry_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentry_setRegisterFuncForRemoveImage(&sentry_register_func_for_remove_image);
    atomic_store(&s_iterationCount, 0);
    s_iterationStarted = dispatch_semaphore_create(0);
}

- (void)tearDown
{
    sentrycrashdl_clearDyld();
    sentry_resetFuncForAddRemoveImage();
    sentrycrashbic_stopCache();
    sentry_setFuncForBeforeAdd(NULL);
}

/**
 * Thread A iterates all cached images via registerAddedCallback (slow — simulated page faults).
 * Thread B calls binaryImageAdded concurrently.
 * Measures how long Thread B is blocked waiting for the mutex.
 * Before fix: ~105ms (entire iteration). After fix: < 1ms.
 */
- (void)testMainThreadBlockingDuringRegisterCallback
{
    sentrycrashbic_startCache();
    int count = 0;
    sentrycrashbic_iterateOverImages(&countImages, &count);
    XCTAssertGreaterThan(count, 0);

    sentrycrashbic_stopCache();
    sentry_setRegisterFuncForAddImage(&sentry_register_func_for_add_image);
    sentrycrashbic_startCache();

    // Thread A: slow iteration over all cached images
    dispatch_semaphore_t threadADone = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        sentrycrashbic_registerAddedCallback(&slowIterationCallback);
        dispatch_semaphore_signal(threadADone);
    });

    intptr_t waitResult = dispatch_semaphore_wait(
        s_iterationStarted, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    XCTAssertEqual(waitResult, 0, @"Thread A should have started iteration");

    // Thread B: concurrent binaryImageAdded — measure how long it's blocked
    NSUInteger extraIndex = MIN(s_machHeaders.count - 1, (NSUInteger)count + 1);
    const struct mach_header *extraHeader = [s_machHeaders[extraIndex] pointerValue];

    __block CFAbsoluteTime blockStart = 0;
    __block CFAbsoluteTime blockEnd = 0;
    dispatch_semaphore_t threadBDone = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        blockStart = CFAbsoluteTimeGetCurrent();
        s_addBinaryImage(extraHeader, 0);
        blockEnd = CFAbsoluteTimeGetCurrent();
        dispatch_semaphore_signal(threadBDone);
    });

    dispatch_semaphore_wait(threadADone, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    dispatch_semaphore_wait(threadBDone, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

    double blockedMs = (blockEnd - blockStart) * 1000.0;

    NSLog(@"METRIC blocked_ms=%.2f", blockedMs);
    NSLog(@"METRIC iterated_images=%d", atomic_load(&s_iterationCount));
    NSLog(@"METRIC cached_images=%d", count);

    XCTAssertLessThan(blockedMs, 50.0,
        @"Thread B was blocked for %.2fms — mutex should not be held during iteration.", blockedMs);
}

@end
