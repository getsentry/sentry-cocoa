#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <pthread.h>
#include <stdio.h>
#include <dispatch/dispatch.h>
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

#include <stdatomic.h>

#define MAX_DYLD_IMAGES 4096

typedef struct {
  _Atomic(uint32_t) ready;        // 0 = not published, 1 = published
  SentryCrashBinaryImage image;
} PublishedBinaryImage;

static PublishedBinaryImage g_images[MAX_DYLD_IMAGES];
static _Atomic(uint32_t) g_next_index = 0;
static _Atomic(uint32_t) g_overflowed = 0;

static void add_dyld_image(const struct mach_header* mh) {
    uint32_t idx =
        atomic_fetch_add_explicit(&g_next_index, 1, memory_order_relaxed);

    if (idx >= MAX_DYLD_IMAGES) {
        atomic_store_explicit(&g_overflowed, 1, memory_order_relaxed);
        return;
    }
    
    Dl_info info;
    if (!dladdr(mh, &info) || info.dli_fname == NULL) {
        return;
    }

    PublishedBinaryImage* entry = &g_images[idx];
    sentrycrashdl_getBinaryImageForHeader(mh, info.dli_fname, &entry->image, false);

    // ---- Publish ----
    atomic_store_explicit(&entry->ready, 1, memory_order_release);
}

static void dyld_add_image_cb(const struct mach_header* mh, intptr_t slide) {
    add_dyld_image(mh);
}

void dyld_tracker_start(void) {
  sentry_dyld_register_func_for_add_image(dyld_add_image_cb);
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    uint32_t count =
        atomic_load_explicit(&g_next_index, memory_order_acquire);

    if (count > MAX_DYLD_IMAGES) count = MAX_DYLD_IMAGES;

    for (uint32_t i = 0; i < count; i++) {
        PublishedBinaryImage* src = &g_images[i];

        if (!atomic_load_explicit(&src->ready, memory_order_acquire)) {
            return; // stop at first unpublished entry
        }

        callback(&src->image, context);
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
bool
sentrycrashbic_shouldAddDyld(void)
{
    // dyld is different from libdyld.dylib; the latter contains the public API
    // (like dlopen, dlsym, dlclose) while the former is the actual dynamic
    // linker executable that handles runtime library loading and symbol resolution
    return sentrycrashdl_imageNamed("/usr/lib/dyld", false) == UINT32_MAX;
}

// Since Apple no longer includes dyld in the images listed `_dyld_image_count` and related
// functions We manually include it to our cache.
void
sentrycrashbic_addDyldNode(void)
{
    const struct mach_header *header = sentryDyldHeader;

    SentryCrashBinaryImage binaryImage = { 0 };
    if (!sentrycrashdl_getBinaryImageForHeader((const void *)header, "dyld", &binaryImage, false)) {
        return;
    }
    add_dyld_image(header);
}

void
sentrycrashbic_startCache(void)
{
    if (sentrycrashbic_shouldAddDyld()) {
        sentrycrashdl_initialize();
        sentrycrashbic_addDyldNode();
    }

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    // This must be done on a background thread to not block app launch due to the extensive use of locks
    // in the image added callback. The main culprit is the calls to `dladdr`.
    // The downside of doing this async is if there is a crash very shortly after app launch we might
    // not have recorded all the load addresses of images yet. We think this is an acceptible tradeoff
    // to not block app launch, since it's always possible to crash early in app launch before
    // Sentry can capture the crash.
    //
    // A future update to this code could record everything but the filename synchronously, and then
    // add in the image name async. However, that would still block app launch somewhat and it's not
    // clear that is worth the benefits.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        dyld_tracker_start();
    });
}

void
sentrycrashbic_stopCache(void)
{
    // TODO: Why do we need to support stopping it?
}

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    // TODO: I think this is only for when we used to have on-device symbolication. Should be able to remove now
}

void
sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    // TODO: I think this is only for when we used to have on-device symbolication. Should be able to remove now
}
