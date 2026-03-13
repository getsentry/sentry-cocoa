#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

static SentryRegisterFunction _sentry_register_func_for_add_image
    = &_dyld_register_func_for_add_image;
static SentryRegisterFunction _sentry_register_func_for_remove_image
    = &_dyld_register_func_for_remove_image;

static void (*SentryWillAddImageCallback)(void) = NULL;

void
sentry_setRegisterFuncForAddImage(SentryRegisterFunction addFunction)
{
    _sentry_register_func_for_add_image = addFunction;
}

void
sentry_setRegisterFuncForRemoveImage(SentryRegisterFunction removeFunction)
{
    _sentry_register_func_for_remove_image = removeFunction;
}

void
sentry_setFuncForBeforeAdd(void (*callback)(void))
{
    SentryWillAddImageCallback = callback;
}

void
sentry_resetFuncForAddRemoveImage(void)
{
    _sentry_register_func_for_add_image = &_dyld_register_func_for_add_image;
    _sentry_register_func_for_remove_image = &_dyld_register_func_for_remove_image;
}

#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _sentry_register_func_for_add_image(CALLBACK);
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _sentry_register_func_for_remove_image(CALLBACK);
#    define _will_add_image()                                                                      \
        if (SentryWillAddImageCallback)                                                            \
            SentryWillAddImageCallback();
#else
#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _dyld_register_func_for_add_image(CALLBACK)
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _dyld_register_func_for_remove_image(CALLBACK)
#    define _will_add_image()
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#define MAX_DYLD_IMAGES 4096

// Entry lifecycle states
#define IMAGE_EMPTY 0   // Slot reserved but data not written, or write failed
#define IMAGE_READY 1   // Published, visible to readers
#define IMAGE_REMOVED 3 // Image was unloaded

typedef struct {
    _Atomic(uint32_t) state;
    SentryCrashBinaryImage image;
} PublishedBinaryImage;

// g_next_index monotonically increases and is never reset (except in test-only reset).
// Each slot is used at most once, so there are no stale state flags from prior runs.
static PublishedBinaryImage g_images[MAX_DYLD_IMAGES];
static _Atomic(uint32_t) g_next_index = 0;

static _Atomic(sentrycrashbic_cacheChangeCallback) g_addedCallback = NULL;
static _Atomic(sentrycrashbic_cacheChangeCallback) g_removedCallback = NULL;

static void
add_dyld_image(const struct mach_header *mh)
{
    // Check dladdr first, before reserving a slot in the array.
    Dl_info info;
    if (!dladdr(mh, &info) || info.dli_fname == NULL) {
        return;
    }

    // Test hook: called just before adding the image
    _will_add_image();

    uint32_t idx = atomic_fetch_add_explicit(&g_next_index, 1, memory_order_relaxed);

    if (idx >= MAX_DYLD_IMAGES) {
        return;
    }

    PublishedBinaryImage *entry = &g_images[idx];

    if (!sentrycrashdl_getBinaryImageForHeader(mh, info.dli_fname, &entry->image, false)) {
        // Leave state as IMAGE_EMPTY so the entry is never published.
        return;
    }

    sentrycrashbic_cacheChangeCallback callback
        = atomic_load_explicit(&g_addedCallback, memory_order_acquire);

    atomic_store_explicit(&entry->state, IMAGE_READY, memory_order_release);

    if (callback != NULL) {
        callback(&entry->image);
    }
}

static void
dyld_add_image_cb(const struct mach_header *mh, intptr_t slide)
{
    add_dyld_image(mh);
}

static void
dyld_remove_image_cb(const struct mach_header *mh, intptr_t slide)
{
    sentrycrashbic_cacheChangeCallback callback
        = atomic_load_explicit(&g_removedCallback, memory_order_acquire);

    uint32_t count = atomic_load_explicit(&g_next_index, memory_order_acquire);
    if (count > MAX_DYLD_IMAGES)
        count = MAX_DYLD_IMAGES;

    for (uint32_t i = 0; i < count; i++) {
        PublishedBinaryImage *src = &g_images[i];
        if (src->image.address == (uintptr_t)mh) {
            atomic_store_explicit(&src->state, IMAGE_REMOVED, memory_order_release);
            if (callback) {
                callback(&src->image);
            }
            return;
        }
    }
}

static void
dyld_tracker_start(void)
{
    sentry_dyld_register_func_for_add_image(dyld_add_image_cb);
    sentry_dyld_register_func_for_remove_image(dyld_remove_image_cb);
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    uint32_t count = atomic_load_explicit(&g_next_index, memory_order_acquire);

    if (count > MAX_DYLD_IMAGES)
        count = MAX_DYLD_IMAGES;

    for (uint32_t i = 0; i < count; i++) {
        PublishedBinaryImage *src = &g_images[i];

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
sentrycrashbic_shouldAddDyld(void)
{
    // dyld is different from libdyld.dylib; the latter contains the public API
    // (like dlopen, dlsym, dlclose) while the former is the actual dynamic
    // linker executable that handles runtime library loading and symbol resolution
    return sentrycrashdl_imageNamed("/usr/lib/dyld", false) == UINT32_MAX;
}

// Since Apple no longer includes dyld in the images listed `_dyld_image_count` and related
// functions We manually include it to our cache.
// Note: This bypasses add_dyld_image() because dladdr() returns NULL for dyld, so we need
// to use sentrycrashdl_getBinaryImageForHeader() directly with a hardcoded filename.
static void
sentrycrashbic_addDyldNode(void)
{
    const struct mach_header *header = sentryDyldHeader;

    uint32_t idx = atomic_fetch_add_explicit(&g_next_index, 1, memory_order_relaxed);
    if (idx >= MAX_DYLD_IMAGES) {
        return;
    }

    PublishedBinaryImage *entry = &g_images[idx];
    if (!sentrycrashdl_getBinaryImageForHeader(
            (const void *)header, "dyld", &entry->image, false)) {
        return;
    }

    atomic_store_explicit(&entry->state, IMAGE_READY, memory_order_release);
}

static void
sentrycrashbic_startCacheImpl(void)
{
    if (sentrycrashbic_shouldAddDyld()) {
        sentrycrashdl_initialize();
        sentrycrashbic_addDyldNode();
    }
    // During this call the callback is invoked synchronously for every existing image.
    dyld_tracker_start();
}

void
sentrycrashbic_startCache(void)
{
    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    // This must be done on a background thread to not block app launch due to the extensive use of
    // locks in the image added callback. The main culprit is the calls to `dladdr`. The downside of
    // doing this async is if there is a crash very shortly after app launch we might not have
    // recorded all the load addresses of images yet. We think this is an acceptible tradeoff to not
    // block app launch, since it's always possible to crash early in app launch before Sentry can
    // capture the crash.
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    sentrycrashbic_startCacheImpl();
#else
    static dispatch_once_t once_token = 0;
    dispatch_once(&once_token, ^{
        dispatch_async(
                       dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ sentrycrashbic_startCacheImpl(); });
    });
#endif
}

void
sentrycrashbic_stopCache(void)
{ }

// Resetting can create race conditions so should only be done in controlled test environments.
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
void
sentry_resetBinaryImageCache(void)
{
    uint32_t count = atomic_load_explicit(&g_next_index, memory_order_relaxed);
    if (count > MAX_DYLD_IMAGES)
        count = MAX_DYLD_IMAGES;
    for (uint32_t i = 0; i < count; i++) {
        atomic_store_explicit(&g_images[i].state, IMAGE_EMPTY, memory_order_relaxed);
    }
    atomic_store_explicit(&g_next_index, 0, memory_order_relaxed);
    atomic_store_explicit(&g_addedCallback, NULL, memory_order_relaxed);
    atomic_store_explicit(&g_removedCallback, NULL, memory_order_relaxed);
}
#endif

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    atomic_store_explicit(&g_addedCallback, callback, memory_order_release);

    if (callback != NULL) {
        // Call for all existing images already in the cache
        uint32_t count = atomic_load_explicit(&g_next_index, memory_order_acquire);
        if (count > MAX_DYLD_IMAGES)
            count = MAX_DYLD_IMAGES;

        for (uint32_t i = 0; i < count; i++) {
            PublishedBinaryImage *src = &g_images[i];
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
    atomic_store_explicit(&g_removedCallback, callback, memory_order_release);
}
