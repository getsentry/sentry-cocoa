#include "SentryCrashBinaryImageCache.h"
#include "SentryAsyncSafeLog.h"
#include "SentryCrashBinaryImageCacheState.h"
#include "SentryCrashDynamicLinker.h"
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_DYLD_IMAGES SENTRYCRASHBIC_MAX_DYLD_IMAGES

// Entry lifecycle states
#define IMAGE_EMPTY 0 // Slot reserved but data not written, or write failed
#define IMAGE_READY 1 // Published, visible to readers
#define IMAGE_REMOVED 3 // Image was unloaded

static SentryCrashBinaryImageCacheState g_defaultCache = {
    .addImageCallback = &_dyld_register_func_for_add_image,
    .removeImageCallback = &_dyld_register_func_for_remove_image,
};
static _Atomic(SentryCrashBinaryImageCacheState *) g_activeCache = &g_defaultCache;

static inline SentryCrashBinaryImageCacheState *
currentCache(void)
{
    return atomic_load_explicit(&g_activeCache, memory_order_acquire);
}

// Returns the number of reserved slots, clamped to the backing array capacity.
static inline uint32_t
reservedSlotCount(SentryCrashBinaryImageCacheState *cache, memory_order loadOrder)
{
    uint32_t count = atomic_load_explicit(&cache->nextIndex, loadOrder);
    return count > MAX_DYLD_IMAGES ? MAX_DYLD_IMAGES : count;
}

static inline void
registerDyldAddImageCallback(
    SentryCrashBinaryImageCacheState *cache, SentryRegisterImageCallback callback)
{
    cache->addImageCallback(callback);
}

static inline void
registerDyldRemoveImageCallback(
    SentryCrashBinaryImageCacheState *cache, SentryRegisterImageCallback callback)
{
    cache->removeImageCallback(callback);
}

static inline void
callBeforeAddImageCallback(SentryCrashBinaryImageCacheState *cache)
{
    // we need this callback only for test verification, it is a noop in prod
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    void (*cb)(void) = cache->beforeAddImageCallback;
    if (cb != NULL) {
        cb();
    }
#else
    (void)cache;
#endif
}

static void
logImageLimitReached(SentryCrashBinaryImageCacheState *cache)
{
    if (!atomic_exchange_explicit(&cache->didLogImageLimitReached, true, memory_order_acq_rel)) {
        SENTRY_ASYNC_SAFE_LOG_ERROR(
            "Binary image cache reached capacity of %d images. New images will not be tracked.",
            MAX_DYLD_IMAGES);
    }
}

static void
addImage(const struct mach_header *header)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();

    // Check dladdr first, before reserving a slot in the array.
    Dl_info info;
    if (!dladdr(header, &info) || info.dli_fname == NULL) {
        return;
    }

    // Test hook: called just before adding the image.
    callBeforeAddImageCallback(cache);

    uint32_t nextIndex = atomic_fetch_add_explicit(&cache->nextIndex, 1, memory_order_relaxed);

    if (nextIndex >= MAX_DYLD_IMAGES) {
        logImageLimitReached(cache);
        return;
    }

    PublishedBinaryImage *entry = &cache->images[nextIndex];

    if (!sentrycrashdl_getBinaryImageForHeader(header, info.dli_fname, &entry->image, false)) {
        // Leave state as IMAGE_EMPTY so the entry is never published.
        return;
    }

    sentrycrashbic_cacheChangeCallback callback
        = atomic_load_explicit(&cache->addedCallback, memory_order_acquire);

    atomic_store_explicit(&entry->state, IMAGE_READY, memory_order_release);

    if (callback != NULL) {
        callback(&entry->image);
    }
}

static void
dyldAddImageCallback(const struct mach_header *mh, intptr_t slide)
{
    addImage(mh);
}

static void
dyldRemoveImageCallback(const struct mach_header *mh, intptr_t slide)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    sentrycrashbic_cacheChangeCallback callback
        = atomic_load_explicit(&cache->removedCallback, memory_order_acquire);

    uint32_t count = reservedSlotCount(cache, memory_order_acquire);

    for (uint32_t i = 0; i < count; i++) {
        PublishedBinaryImage *src = &cache->images[i];
        if (atomic_load_explicit(&src->state, memory_order_acquire) != IMAGE_READY) {
            continue;
        }
        if (src->image.address == (uintptr_t)mh) {
            atomic_store_explicit(&src->state, IMAGE_REMOVED, memory_order_release);
            if (callback != NULL) {
                callback(&src->image);
            }
            return;
        }
    }
}

static void
startDyldTracking(void)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    registerDyldAddImageCallback(cache, dyldAddImageCallback);
    registerDyldRemoveImageCallback(cache, dyldRemoveImageCallback);
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    uint32_t count = reservedSlotCount(cache, memory_order_acquire);

    for (uint32_t i = 0; i < count; i++) {
        PublishedBinaryImage *src = &cache->images[i];

        if (atomic_load_explicit(&src->state, memory_order_acquire) == IMAGE_READY) {
            callback(&src->image, context);
        }
    }
}

/** Check if dyld should be added to the binary image cache.
 *
 * Since Apple no longer includes dyld in the images listed by _dyld_image_count and related
 * functions, we need to check if dyld is already present in our cache before adding it.
 *
 * @return true if dyld is not found in the loaded images and should be added to the cache,
 *         false if dyld is already present in the loaded images.
 */
static bool
shouldAddDyld(void)
{
    // dyld is different from libdyld.dylib; the latter contains the public API
    // (like dlopen, dlsym, dlclose) while the former is the actual dynamic
    // linker executable that handles runtime library loading and symbol resolution
    return sentrycrashdl_imageNamed("/usr/lib/dyld", false) == UINT32_MAX;
}

// Since Apple no longer includes dyld in the images listed `_dyld_image_count` and related
// functions we manually include it in the cache.
// Note: This bypasses addImage() because dladdr() returns NULL for dyld, so we
// need to use sentrycrashdl_getBinaryImageForHeader() directly with a hardcoded filename.
static void
addDyldImage(void)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    const struct mach_header *header = sentryDyldHeader;

    uint32_t idx = atomic_fetch_add_explicit(&cache->nextIndex, 1, memory_order_relaxed);
    if (idx >= MAX_DYLD_IMAGES) {
        logImageLimitReached(cache);
        return;
    }

    PublishedBinaryImage *entry = &cache->images[idx];
    if (!sentrycrashdl_getBinaryImageForHeader(
            (const void *)header, "dyld", &entry->image, false)) {
        return;
    }

    atomic_store_explicit(&entry->state, IMAGE_READY, memory_order_release);

    sentrycrashbic_cacheChangeCallback callback
        = atomic_load_explicit(&cache->addedCallback, memory_order_acquire);
    if (callback != NULL) {
        callback(&entry->image);
    }
}

static void
startCacheImpl(void)
{
    if (shouldAddDyld()) {
        sentrycrashdl_initialize();
        addDyldImage();
    }
    // During this call the callback is invoked synchronously for every existing image.
    startDyldTracking();
}

void
sentrycrashbic_startCache(void)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    if (atomic_exchange_explicit(&cache->trackingStarted, true, memory_order_acq_rel)) {
        return;
    }

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image.
    // This must be done on a background thread to not block app launch due to the extensive use of
    // locks in the image added callback. The main culprit is the calls to `dladdr`. The downside of
    // doing this async is if there is a crash very shortly after app launch we might not have
    // recorded all the load addresses of images yet. We think this is an acceptible tradeoff to not
    // block app launch, since it's always possible to crash early in app launch before Sentry can
    // capture the crash.
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    startCacheImpl();
#else
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ startCacheImpl(); });
#endif
}

void
sentrycrashbic_stopCache(void)
{
    // Intentionally left running. Once bootstrapped, the canonical C cache keeps tracking loaded
    // images so crashes can still be symbolicated even if higher-level consumers temporarily stop.
}

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
void
sentrycrashbic_setActiveCacheState(SentryCrashBinaryImageCacheState *cache)
{
    if (cache == NULL) {
        cache = &g_defaultCache;
    }
    atomic_store_explicit(&g_activeCache, cache, memory_order_release);
}
#endif

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    atomic_store_explicit(&cache->addedCallback, callback, memory_order_release);

    if (callback != NULL) {
        // Call for all existing images already in the cache
        uint32_t count = reservedSlotCount(cache, memory_order_acquire);

        for (uint32_t i = 0; i < count; i++) {
            PublishedBinaryImage *src = &cache->images[i];
            if (atomic_load_explicit(&src->state, memory_order_acquire) != IMAGE_READY) {
                continue;
            }
            callback(&src->image);
        }
    }
}

void
sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    atomic_store_explicit(&cache->removedCallback, callback, memory_order_release);
}
