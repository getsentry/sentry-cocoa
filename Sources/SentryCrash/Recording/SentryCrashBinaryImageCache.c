#include "SentryCrashBinaryImageCache.h"
#include "SentryAsyncSafeLog.h"
#include "SentryCrashDynamicLinker.h"
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#define MAX_DYLD_IMAGES 4096

// Entry lifecycle states
#define IMAGE_EMPTY 0 // Slot reserved but data not written, or write failed
#define IMAGE_READY 1 // Published, visible to readers
#define IMAGE_REMOVED 3 // Image was unloaded

typedef struct {
    _Atomic(uint32_t) state; // IMAGE_* lifecycle for this slot.
    SentryCrashBinaryImage image; // Stored image snapshot once the slot is published.
} PublishedBinaryImage;

typedef struct {
    // Canonical append-only storage for all published images in this cache state.
    PublishedBinaryImage images[MAX_DYLD_IMAGES];
    // Next slot to reserve. In production this only increases for the process lifetime.
    _Atomic(uint32_t) nextIndex;

    // Consumer callback invoked for newly published images and for replay during registration.
    _Atomic(sentrycrashbic_cacheChangeCallback) addedCallback;
    // Consumer callback invoked when a previously published image is marked removed.
    _Atomic(sentrycrashbic_cacheChangeCallback) removedCallback;

    // Guards the one-time dyld bootstrap/registration for the currently active cache state.
    _Atomic(bool) trackingStarted;
    // Guards the one-time capacity warning for the currently active cache state.
    _Atomic(bool) didLogImageLimitReached;

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    // Test/debug override for `_dyld_register_func_for_add_image()`.
    SentryRegisterFunction registerFuncForAddImage;
    // Test/debug override for `_dyld_register_func_for_remove_image()`.
    SentryRegisterFunction registerFuncForRemoveImage;
    // Test hook invoked immediately before a new image enters the add path.
    void (*willAddImageCallback)(void);
#endif
} SentryCrashBinaryImageCacheState;

static SentryCrashBinaryImageCacheState g_defaultCache = {
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    .registerFuncForAddImage = &_dyld_register_func_for_add_image,
    .registerFuncForRemoveImage = &_dyld_register_func_for_remove_image,
#endif
};
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
static SentryCrashBinaryImageCacheState g_testCache = {
    .registerFuncForAddImage = &_dyld_register_func_for_add_image,
    .registerFuncForRemoveImage = &_dyld_register_func_for_remove_image,
};
#endif
static _Atomic(SentryCrashBinaryImageCacheState *) g_activeCache = &g_defaultCache;

static inline SentryCrashBinaryImageCacheState *
currentCache(void)
{
    return atomic_load_explicit(&g_activeCache, memory_order_acquire);
}

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
static void
resetState(SentryCrashBinaryImageCacheState *cache)
{
    uint32_t count = atomic_load_explicit(&cache->nextIndex, memory_order_relaxed);
    if (count > MAX_DYLD_IMAGES) {
        count = MAX_DYLD_IMAGES;
    }
    for (uint32_t i = 0; i < count; i++) {
        atomic_store_explicit(&cache->images[i].state, IMAGE_EMPTY, memory_order_relaxed);
    }
    atomic_store_explicit(&cache->nextIndex, 0, memory_order_relaxed);
    atomic_store_explicit(&cache->addedCallback, NULL, memory_order_relaxed);
    atomic_store_explicit(&cache->removedCallback, NULL, memory_order_relaxed);
    atomic_store_explicit(&cache->trackingStarted, false, memory_order_relaxed);
    atomic_store_explicit(&cache->didLogImageLimitReached, false, memory_order_relaxed);
    cache->registerFuncForAddImage = &_dyld_register_func_for_add_image;
    cache->registerFuncForRemoveImage = &_dyld_register_func_for_remove_image;
    cache->willAddImageCallback = NULL;
}
#endif

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

void
sentrycrashbic_setRegisterFuncForAddImage(SentryRegisterFunction addFunction)
{
    currentCache()->registerFuncForAddImage = addFunction;
}

void
sentrycrashbic_setRegisterFuncForRemoveImage(SentryRegisterFunction removeFunction)
{
    currentCache()->registerFuncForRemoveImage = removeFunction;
}

void
sentrycrashbic_setBeforeAddImageCallback(void (*callback)(void))
{
    currentCache()->willAddImageCallback = callback;
}

#    define registerDyldAddImageCallback(CALLBACK)                                                 \
        do {                                                                                       \
            currentCache()->registerFuncForAddImage(CALLBACK);                                     \
        } while (0)
#    define registerDyldRemoveImageCallback(CALLBACK)                                              \
        do {                                                                                       \
            currentCache()->registerFuncForRemoveImage(CALLBACK);                                  \
        } while (0)
#    define callWillAddImageCallback()                                                             \
        do {                                                                                       \
            void (*cb)(void) = currentCache()->willAddImageCallback;                               \
            if (cb != NULL) {                                                                      \
                cb();                                                                              \
            }                                                                                      \
        } while (0)
#else
#    define registerDyldAddImageCallback(CALLBACK) _dyld_register_func_for_add_image(CALLBACK)
#    define registerDyldRemoveImageCallback(CALLBACK) _dyld_register_func_for_remove_image(CALLBACK)
#    define callWillAddImageCallback()                                                             \
        do {                                                                                       \
        } while (0)
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

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

    // Test hook: called just before adding the image
    callWillAddImageCallback();

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

    uint32_t count = atomic_load_explicit(&cache->nextIndex, memory_order_acquire);
    if (count > MAX_DYLD_IMAGES) {
        count = MAX_DYLD_IMAGES;
    }

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
    registerDyldAddImageCallback(dyldAddImageCallback);
    registerDyldRemoveImageCallback(dyldRemoveImageCallback);
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    uint32_t count = atomic_load_explicit(&cache->nextIndex, memory_order_acquire);

    if (count > MAX_DYLD_IMAGES) {
        count = MAX_DYLD_IMAGES;
    }

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

// Resetting can create race conditions so should only be done in controlled test environments.
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
void
sentrycrashbic_useFreshTestCacheState(void)
{
    resetState(&g_testCache);
    atomic_store_explicit(&g_activeCache, &g_testCache, memory_order_release);
}

void
sentrycrashbic_useDefaultCacheState(void)
{
    resetState(&g_defaultCache);
    atomic_store_explicit(&g_activeCache, &g_defaultCache, memory_order_release);
}
#endif

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    SentryCrashBinaryImageCacheState *cache = currentCache();
    atomic_store_explicit(&cache->addedCallback, callback, memory_order_release);

    if (callback != NULL) {
        // Call for all existing images already in the cache
        uint32_t count = atomic_load_explicit(&cache->nextIndex, memory_order_acquire);
        if (count > MAX_DYLD_IMAGES) {
            count = MAX_DYLD_IMAGES;
        }

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
